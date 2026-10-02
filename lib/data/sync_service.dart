import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market_session.dart';
import '../models/product.dart';
import 'local_image_storage.dart';
import 'local_database.dart';

class SyncReport {
  const SyncReport({required this.pendingCount, this.error});

  final int pendingCount;
  final String? error;
  bool get succeeded => error == null;
}

typedef SyncProgressCallback = void Function(
  int loadedProducts,
  int totalProducts,
);

class SyncService {
  SyncService(
    this._database,
    this._client, {
    this.imageStorage = const LocalImageStorage(),
    this.requestTimeout = const Duration(seconds: 12),
  });

  final LocalDatabase _database;
  final LocalImageStorage imageStorage;
  final Duration requestTimeout;
  final SupabaseClient? _client;
  final StreamController<void> _remoteChanges =
      StreamController<void>.broadcast();
  final StreamController<void> _localChanges =
      StreamController<void>.broadcast();
  final Map<String, ProductImageData> _thumbnailBacklog = {};
  final Set<String> _thumbnailInFlight = {};
  Future<void>? _thumbnailTask;
  bool _needsAccessValidation = true;
  bool _isRunning = false;
  bool _isDisposed = false;
  MarketSession? _marketSession;
  RealtimeChannel? _realtimeChannel;
  String? _realtimeMarketId;

  bool get isConfigured => _client != null;
  MarketSession? get marketSession => _marketSession;
  bool get hasMarketAccess => _marketSession != null;
  bool get canEdit => _marketSession?.canEdit ?? false;
  Stream<void> get remoteChanges => _remoteChanges.stream;
  Stream<void> get localChanges => _localChanges.stream;

  Future<void> initialize() async {
    final client = _client;
    if (client == null) {
      _marketSession = const MarketSession(
        marketId: LocalDatabase.localMarketId,
        accessLevel: MarketAccessLevel.editor,
      );
      _database.setActiveMarket(LocalDatabase.localMarketId);
      return;
    }

    final saved = await _database.loadSavedMarketSession();
    if (saved != null && saved.marketId != LocalDatabase.localMarketId) {
      _setMarketSession(saved);
    }

    // Startup only reads local state. Authentication and market validation
    // belong to the background sync, never before the first visible frame.
  }

  Future<void> enterMarket({required String marketNumber, String? pin}) async {
    final client = _client;
    if (client == null) throw StateError('Supabase ist nicht eingerichtet.');
    await _ensureAnonymousSession();
    final response = await client.rpc(
      'enter_market',
      params: {
        'p_market_number': marketNumber.trim(),
        'p_pin': pin?.trim().isEmpty == true ? null : pin?.trim(),
      },
    );
    final session = _sessionFromRpc(response);
    if (session == null) throw StateError('Marktzugang fehlgeschlagen.');
    if (session.canEdit) {
      await _database.adoptLegacyDataForMarket(session.marketId);
    }
    await _persistMarketSession(session);
  }

  Future<void> upgradeToEditor(String pin) async {
    final client = _client;
    if (client == null || _marketSession == null) {
      throw StateError('Es ist kein Markt geöffnet.');
    }
    await _ensureAnonymousSession();
    final response = await client.rpc(
      'upgrade_market_access',
      params: {'p_pin': pin.trim()},
    );
    final session = _sessionFromRpc(response);
    if (session == null || !session.canEdit) {
      throw StateError('PIN ist falsch.');
    }
    await _persistMarketSession(session);
  }

  Future<void> leaveMarket() async {
    final client = _client;
    try {
      if (client?.auth.currentUser != null && _marketSession != null) {
        await client!.rpc('leave_market');
      }
    } catch (_) {
      // Leaving the local market session must also work while offline.
    } finally {
      await _clearMarketSession();
      try {
        await client?.auth.signOut();
      } catch (_) {
        // Local access must still be removed when the device is offline.
      }
    }
  }

  Future<SyncReport> synchronize({SyncProgressCallback? onProgress}) async {
    if (_client == null) {
      return SyncReport(pendingCount: await _database.pendingCount());
    }
    if (_isRunning) {
      return SyncReport(pendingCount: await _database.pendingCount());
    }

    _isRunning = true;
    try {
      if (!hasMarketAccess) {
        throw const AuthException('Bitte zuerst einen Markt öffnen.');
      }
      if (_needsAccessValidation) {
        final cachedSession = _marketSession;
        await _ensureAnonymousSession().timeout(requestTimeout);
        final response = await _client
            .rpc('current_market_access')
            .timeout(requestTimeout);
        if (_isDisposed || !identical(cachedSession, _marketSession)) {
          return SyncReport(pendingCount: await _database.pendingCount());
        }
        final restored = _sessionFromRpc(response);
        if (restored == null) {
          await _clearMarketSession();
          throw const AuthException('Bitte den Markt erneut öffnen.');
        }
        await _persistMarketSession(restored);
      }
      if (canEdit) await _pushPendingChanges();
      await _pullRemoteChanges(onProgress: onProgress);
      final marketId = _marketSession!.marketId;
      final plan = await _client
          .from('cashier_plans')
          .select('data')
          .eq('market_id', marketId)
          .maybeSingle()
          .timeout(requestTimeout);
      if (plan != null) {
        await _database.applyRemoteCashierPlan(
          marketId,
          Map<String, dynamic>.from(plan['data'] as Map),
        );
      }
      return SyncReport(pendingCount: await _database.pendingCount());
    } catch (error) {
      return SyncReport(
        pendingCount: await _database.pendingCount(),
        error: _friendlyError(error),
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _pushPendingChanges() async {
    final client = _client!;
    final marketId = _marketSession!.marketId;
    final queue = await _database.getQueue();
    for (final entry in queue) {
      try {
        if (entry.action == 'cashier_plan') {
          await client.rpc(
            'apply_cashier_plan_changes',
            params: {'p_market_id': marketId, 'p_changes': entry.payload},
          );
        } else if (entry.action == 'delete') {
          await client
              .from('products')
              .update({'deleted_at': entry.payload['deleted_at']})
              .eq('id', entry.productId)
              .eq('market_id', marketId);
        } else {
          await _pushProduct(entry);
        }
        await _database.completeQueueEntry(entry.id);
      } catch (error) {
        await _database.failQueueEntry(entry.id, error);
        rethrow;
      }
    }
  }

  Future<void> _pushProduct(SyncQueueEntry entry) async {
    final client = _client!;
    final marketId = _marketSession!.marketId;
    // Liest immer den neuesten lokalen Stand. So bleiben auch Sync-Aufträge aus
    // älteren App-Versionen mit dem erweiterten Bilder-/Alias-Schema kompatibel.
    final localProduct = await _database.getProduct(entry.productId);
    if (localProduct == null) return;
    final productMap = Map<String, dynamic>.from(localProduct.toRemoteMap());
    final codeMaps = localProduct.codes
        .map((code) => Map<String, dynamic>.from(code.toRemoteMap()))
        .toList();
    final imageMaps = localProduct.images
        .map((image) => Map<String, dynamic>.from(image.toQueueMap()))
        .toList();

    productMap
      ..remove('image_path')
      ..remove('image_url')
      ..['market_id'] = marketId
      ..['deleted_at'] = null;
    final remoteImages = <Map<String, dynamic>>[];
    for (final imageMap in imageMaps) {
      String? remoteUrl = imageMap['remote_url'] as String?;
      String? remoteThumbnailUrl = imageMap['remote_thumbnail_url'] as String?;
      final localPath = imageMap['local_path'] as String?;
      if ((remoteUrl == null || remoteUrl.isEmpty) &&
          localPath != null &&
          localPath.isNotEmpty) {
        final bytes = await imageStorage.readBytes(localPath);
        if (bytes != null) {
          final extension = imageStorage.extensionFor(localPath);
          final remotePath = storagePathForProductImage(
            currentUrl: remoteUrl,
            marketId: marketId,
            productId: entry.productId,
            fileStem: imageMap['id'] as String,
            fallbackExtension: extension,
          );
          await client.storage
              .from('product-images')
              .uploadBinary(
                remotePath,
                bytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: _contentTypeForExtension(extension),
                ),
              );
          remoteUrl = client.storage
              .from('product-images')
              .getPublicUrl(remotePath);
        }
      }
      final localThumbnailPath = imageMap['local_thumbnail_path'] as String?;
      if ((remoteThumbnailUrl == null || remoteThumbnailUrl.isEmpty) &&
          localThumbnailPath != null &&
          localThumbnailPath.isNotEmpty) {
        final thumbnailBytes = await imageStorage.readBytes(localThumbnailPath);
        if (thumbnailBytes != null) {
          final extension = imageStorage.extensionFor(localThumbnailPath);
          final remotePath = storagePathForProductImage(
            currentUrl: remoteThumbnailUrl,
            marketId: marketId,
            productId: entry.productId,
            fileStem: '${imageMap['id']}_thumb',
            fallbackExtension: extension,
          );
          await client.storage
              .from('product-images')
              .uploadBinary(
                remotePath,
                thumbnailBytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: _contentTypeForExtension(extension),
                ),
              );
          remoteThumbnailUrl = client.storage
              .from('product-images')
              .getPublicUrl(remotePath);
        }
      }
      if (remoteUrl != null) {
        await _database.updateRemoteImageUrls(
          imageMap['id'] as String,
          imageUrl: remoteUrl,
          thumbnailUrl: remoteThumbnailUrl,
        );
      }
      remoteImages.add(
        imageMap
          ..remove('local_path')
          ..remove('local_thumbnail_path')
          ..['remote_url'] = remoteUrl
          ..['remote_thumbnail_url'] = remoteThumbnailUrl,
      );
    }

    // Erst nach möglicherweise längeren Datei-Uploads werden die sichtbaren
    // Datenbankzeilen ausgetauscht. Andere Geräte behalten bis dahin den
    // letzten vollständigen Bildstand und erhalten anschließend ein Live-Event.
    await client.from('products').upsert(productMap);

    // Der lokale Produktstand ist maßgeblich. Durch das vorherige Entfernen
    // verschwinden auch Codes in Supabase, die im Formular gelöscht wurden.
    // Gleichzeitig kann der aktive Code ohne Konflikt mit dem partiellen
    // Unique-Index gewechselt werden.
    await client
        .from('product_codes')
        .delete()
        .eq('product_id', entry.productId);
    if (codeMaps.isNotEmpty) {
      await client.from('product_codes').upsert(codeMaps);
    }

    await client
        .from('product_images')
        .delete()
        .eq('product_id', entry.productId);
    if (remoteImages.isNotEmpty) {
      await client.from('product_images').upsert(remoteImages);
    }
  }

  Future<List<Map<String, dynamic>>> _readTable(
    String table,
    String marketId,
  ) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += pageSize) {
      var query = _client!.from(table).select();
      if (table == 'products') query = query.eq('market_id', marketId);
      final page = await query
          .order('id')
          .range(offset, offset + pageSize - 1)
          .timeout(requestTimeout);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }

  Future<void> _pullRemoteChanges({SyncProgressCallback? onProgress}) async {
    final marketId = _marketSession!.marketId;
    // Independent requests run together; pagination prevents the API row limit
    // from silently dropping products, codes or images in larger markets.
    final snapshots = await Future.wait([
      _readTable('products', marketId),
      _readTable('product_codes', marketId),
      _readTable('product_images', marketId),
    ]);
    if (_isDisposed || _marketSession?.marketId != marketId) return;
    final rawProducts = snapshots[0];
    final total = rawProducts.where((row) => row['deleted_at'] == null).length;
    onProgress?.call(0, total);
    final localProducts = {
      for (final product in await _database.getProducts()) product.id: product,
    };
    final pending = (await _database.getQueue())
        .map((entry) => entry.productId)
        .toSet();
    final codesByProduct = <String, List<ProductCode>>{};
    final imagesByProduct = <String, List<Map<String, dynamic>>>{};
    for (final row in snapshots[1]) {
      final code = ProductCode.fromRemoteMap(row);
      codesByProduct.putIfAbsent(code.productId, () => []).add(code);
    }
    for (final row in snapshots[2]) {
      imagesByProduct
          .putIfAbsent(row['product_id'] as String, () => [])
          .add(row);
    }
    final changed = <Product>[];
    final deleted = <String>[];
    final thumbnails = <ProductImageData>[];
    for (final row in rawProducts) {
      final id = row['id'] as String;
      if (pending.contains(id)) continue;
      final existing = localProducts[id];
      if (row['deleted_at'] != null) {
        if (existing != null) deleted.add(id);
        continue;
      }
      final existingImages = {
        for (final image in existing?.images ?? <ProductImageData>[])
          image.id: image,
      };
      final images = (imagesByProduct[id] ?? []).map((imageRow) {
        final cached = existingImages[imageRow['id']];
        return ProductImageData.fromRemoteMap(
          imageRow,
          existingLocalPath: cached?.remoteUrl == imageRow['remote_url']
              ? cached?.localPath
              : null,
          existingLocalThumbnailPath:
              cached?.remoteThumbnailUrl == imageRow['remote_thumbnail_url']
              ? cached?.localThumbnailPath
              : null,
        );
      }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final remote = Product.fromRemoteMap(
        row,
        codesByProduct[id] ?? [],
        images: images,
      );
      // Child rows can change independently. Compare their contents too, while
      // excluding local image bytes from the comparison.
      if (existing == null ||
          _remoteContent(existing) != _remoteContent(remote)) {
        changed.add(remote);
      }
      thumbnails.addAll(images);
    }
    if (_isDisposed || _marketSession?.marketId != marketId) return;
    await _database.applyRemoteChanges(
      marketId: marketId,
      products: changed,
      deletedIds: deleted,
    );
    onProgress?.call(total, total);
    _scheduleThumbnails(thumbnails);
  }

  String _remoteContent(Product product) {
    final codes = [...product.codes]..sort((a, b) => a.id.compareTo(b.id));
    final images = [...product.images]..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode({
      'product': product.toRemoteMap(),
      'codes': codes.map((code) => code.toRemoteMap()).toList(),
      'images': images.map((image) => image.toRemoteMap()).toList(),
    });
  }

  void _scheduleThumbnails(List<ProductImageData> images) {
    if (_isDisposed) return;
    for (final image in images) {
      if (image.remoteThumbnailUrl == null ||
          image.remoteThumbnailUrl!.isEmpty) {
        continue;
      }
      final key = '${image.id}:${image.remoteThumbnailUrl}';
      if (!_thumbnailInFlight.contains(key)) _thumbnailBacklog[key] = image;
    }
    _startThumbnailWorker();
  }

  void _startThumbnailWorker() {
    final marketId = _marketSession?.marketId;
    if (_isDisposed ||
        marketId == null ||
        _thumbnailTask != null ||
        _thumbnailBacklog.isEmpty) {
      return;
    }
    _thumbnailTask = _cacheThumbnails(marketId)
        .catchError((Object _) {
          // Failed background cache writes will be retried on the next sync.
        })
        .whenComplete(() {
          _thumbnailTask = null;
          if (!_isDisposed && _thumbnailBacklog.isNotEmpty) {
            _startThumbnailWorker();
          }
        });
  }

  Future<void> _cacheThumbnails(String marketId) async {
    var changed = false;
    while (!_isDisposed &&
        _marketSession?.marketId == marketId &&
        _thumbnailBacklog.isNotEmpty) {
      // Bound concurrency so image downloads do not flood the connection.
      final keys = _thumbnailBacklog.keys.take(4).toList();
      final jobs = keys.map((key) => _thumbnailBacklog.remove(key)!).toList();
      _thumbnailInFlight.addAll(keys);
      try {
        final results = await Future.wait(
          jobs.map((image) async {
            try {
              if (image.localThumbnailPath != null &&
                  await imageStorage.exists(image.localThumbnailPath!)) {
                return null;
              }
              final path = await imageStorage.cacheImageFromUrl(
                image.remoteThumbnailUrl!,
                thumbnail: true,
              );
              return MapEntry(image, path);
            } catch (_) {
              return null;
            }
          }),
        );
        if (_isDisposed || _marketSession?.marketId != marketId) break;
        final paths = Map<ProductImageData, String>.fromEntries(
          results.whereType<MapEntry<ProductImageData, String>>(),
        );
        await _database.storeRemoteThumbnails(marketId, paths);
        changed |= paths.isNotEmpty;
      } finally {
        _thumbnailInFlight.removeAll(keys);
      }
    }
    if (changed && !_isDisposed && _marketSession?.marketId == marketId) {
      _localChanges.add(null);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('cashier_plan')) {
      return 'Der Kassenplan konnte nicht synchronisiert werden. '
          'Bitte das aktuelle supabase/schema.sql im SQL Editor ausführen. '
          'Lokale Änderungen bleiben gespeichert.';
    }
    if (text.contains('MARKET_ACCESS_DENIED')) {
      return 'Marktnummer oder PIN ist falsch.';
    }
    if (text.contains('MARKET_PIN_DENIED')) {
      return 'PIN ist falsch.';
    }
    if (text.contains('remote_thumbnail_url')) {
      return 'Die Cloud-Datenbank unterstützt Bild-Thumbnails noch nicht. '
          'Bitte das aktuelle supabase/schema.sql im SQL Editor ausführen.';
    }
    final normalized = text.toLowerCase();
    if (normalized.contains('row-level security') ||
        normalized.contains('row level security') ||
        normalized.contains('statuscode: 403')) {
      return 'Supabase blockiert den Cloud-Bildzugriff per RLS. Bitte das '
          'aktuelle supabase/schema.sql im SQL Editor erneut ausführen.';
    }
    if (text.length > 180) return '${text.substring(0, 177)}…';
    return text;
  }

  Future<void> _ensureAnonymousSession() async {
    final client = _client!;
    final currentUser = client.auth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) return;
    if (currentUser != null) await client.auth.signOut();
    await client.auth.signInAnonymously();
  }

  MarketSession? _sessionFromRpc(dynamic response) {
    final dynamic row = response is List
        ? (response.isEmpty ? null : response.first)
        : response;
    if (row == null) return null;
    return MarketSession.fromRpc(Map<String, dynamic>.from(row as Map));
  }

  void _setMarketSession(MarketSession? session) {
    if (_marketSession?.marketId != session?.marketId) {
      _thumbnailBacklog.clear();
    }
    _marketSession = session;
    _database.setActiveMarket(session?.marketId);
  }

  Future<void> _persistMarketSession(MarketSession session) async {
    final previous = _marketSession;
    _setMarketSession(session);
    _needsAccessValidation = false;
    if (previous?.marketId != session.marketId ||
        previous?.accessLevel != session.accessLevel) {
      await _database.saveMarketSession(session);
    }
    await _restartRealtimeSubscription();
  }

  Future<void> _clearMarketSession() async {
    _setMarketSession(null);
    await _stopRealtimeSubscription();
    await _database.clearMarketSession();
  }

  Future<void> _restartRealtimeSubscription() async {
    final client = _client;
    final marketId = _marketSession?.marketId;
    if (_isDisposed || client == null || marketId == null) {
      await _stopRealtimeSubscription();
      return;
    }
    if (_realtimeChannel != null && _realtimeMarketId == marketId) return;

    await _stopRealtimeSubscription();
    if (_isDisposed || _marketSession?.marketId != marketId) return;

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'market_id',
      value: marketId,
    );
    final channel = client.channel('market-products-$marketId');
    _realtimeChannel = channel;
    _realtimeMarketId = marketId;

    void notifyRemoteChange(PostgresChangePayload _) {
      if (!_isDisposed &&
          identical(_realtimeChannel, channel) &&
          _marketSession?.marketId == marketId) {
        _remoteChanges.add(null);
      }
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cashier_plans',
          filter: filter,
          callback: notifyRemoteChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'products',
          filter: filter,
          callback: notifyRemoteChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'products',
          filter: filter,
          callback: notifyRemoteChange,
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed &&
              !_isDisposed &&
              identical(_realtimeChannel, channel) &&
              _marketSession?.marketId == marketId) {
            // Holt auch Änderungen nach, die zwischen dem letzten normalen
            // Sync und dem erfolgreichen WebSocket-Abonnement passiert sind.
            _remoteChanges.add(null);
          }
        });
  }

  Future<void> _stopRealtimeSubscription() async {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeMarketId = null;
    if (channel == null) return;
    try {
      await _client?.removeChannel(channel);
    } catch (_) {
      // Der Kanal wird lokal bereits nicht mehr verwendet. Ein fehlgeschlagenes
      // Abmelden darf Marktwechsel und Offline-Betrieb nicht blockieren.
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _thumbnailBacklog.clear();
    await _stopRealtimeSubscription();
    await _remoteChanges.close();
    await _localChanges.close();
  }
}

String storagePathForProductImage({
  required String? currentUrl,
  required String marketId,
  required String productId,
  required String fileStem,
  required String fallbackExtension,
}) {
  final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
  final segments = uri?.pathSegments ?? const <String>[];
  final bucketIndex = segments.indexOf('product-images');
  if (bucketIndex >= 0) {
    final objectSegments = segments.skip(bucketIndex + 1).toList();
    if (objectSegments.length == 3 &&
        objectSegments[0] == marketId &&
        objectSegments[1] == productId) {
      final fileName = objectSegments[2];
      final extensionIndex = fileName.lastIndexOf('.');
      final existingStem = extensionIndex < 0
          ? fileName
          : fileName.substring(0, extensionIndex);
      if (existingStem == fileStem) return objectSegments.join('/');
    }
  }
  return '$marketId/$productId/$fileStem$fallbackExtension';
}

String _contentTypeForExtension(String extension) =>
    switch (extension.toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };
