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

class SyncService {
  SyncService(this._database, this._client);

  final LocalDatabase _database;
  final LocalImageStorage _imageStorage = const LocalImageStorage();
  final SupabaseClient? _client;
  bool _isRunning = false;
  MarketSession? _marketSession;

  bool get isConfigured => _client != null;
  MarketSession? get marketSession => _marketSession;
  bool get hasMarketAccess => _marketSession != null;
  bool get canEdit => _marketSession?.canEdit ?? false;

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

    try {
      await _ensureAnonymousSession();
      final response = await client.rpc('current_market_access');
      final restored = _sessionFromRpc(response);
      if (restored == null) {
        await _clearMarketSession();
      } else {
        await _persistMarketSession(restored);
      }
    } catch (_) {
      // A cached market remains usable offline. Server-side RLS still validates
      // its access level before the next synchronization.
    }
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

  Future<SyncReport> synchronize() async {
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
      if (canEdit) await _pushPendingChanges();
      await _pullRemoteChanges();
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
        if (entry.action == 'delete') {
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
    await client.from('products').upsert(productMap);

    if (codeMaps.isNotEmpty) {
      // Verhindert beim Wechsel des aktiven Codes einen kurzzeitigen Konflikt
      // mit dem partiellen Unique-Index in Supabase.
      await client
          .from('product_codes')
          .update({'is_active': false})
          .eq('product_id', entry.productId);
      await client.from('product_codes').upsert(codeMaps);
    }

    await client
        .from('product_images')
        .delete()
        .eq('product_id', entry.productId);
    final remoteImages = <Map<String, dynamic>>[];
    for (final imageMap in imageMaps) {
      String? remoteUrl = imageMap['remote_url'] as String?;
      final localPath = imageMap['local_path'] as String?;
      if (localPath != null && localPath.isNotEmpty) {
        final bytes = await _imageStorage.readBytes(localPath);
        if (bytes != null) {
          final extension = _imageStorage.extensionFor(localPath);
          final remotePath =
              '$marketId/${entry.productId}/${imageMap['id']}$extension';
          await client.storage
              .from('product-images')
              .uploadBinary(
                remotePath,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );
          remoteUrl = client.storage
              .from('product-images')
              .getPublicUrl(remotePath);
          await _database.updateRemoteImageUrl(
            imageMap['id'] as String,
            remoteUrl,
          );
        }
      }
      remoteImages.add(
        imageMap
          ..remove('local_path')
          ..['remote_url'] = remoteUrl,
      );
    }
    if (remoteImages.isNotEmpty) {
      await client.from('product_images').upsert(remoteImages);
    }
  }

  Future<void> _pullRemoteChanges() async {
    final client = _client!;
    final rawProducts = await client.from('products').select();
    final rawCodes = await client.from('product_codes').select();
    final rawImages = await client.from('product_images').select();
    final codeMapsByProduct = <String, List<Map<String, dynamic>>>{};
    final imageMapsByProduct = <String, List<Map<String, dynamic>>>{};
    for (final rawCode in rawCodes) {
      final codeMap = Map<String, dynamic>.from(rawCode);
      final productId = codeMap['product_id'] as String;
      codeMapsByProduct.putIfAbsent(productId, () => []).add(codeMap);
    }
    for (final rawImage in rawImages) {
      final imageMap = Map<String, dynamic>.from(rawImage);
      final productId = imageMap['product_id'] as String;
      imageMapsByProduct.putIfAbsent(productId, () => []).add(imageMap);
    }

    for (final rawProduct in rawProducts) {
      final productMap = Map<String, dynamic>.from(rawProduct);
      final productId = productMap['id'] as String;
      if (await _database.hasPendingChange(productId)) continue;
      if (productMap['deleted_at'] != null) {
        await _database.deleteProduct(productId, enqueue: false);
        continue;
      }

      final existing = await _database.getProduct(productId);
      final remoteUpdated = DateTime.parse(productMap['updated_at'] as String);
      if (existing != null &&
          !remoteUpdated.isAfter(existing.updatedAt.toUtc())) {
        continue;
      }
      final codes = (codeMapsByProduct[productId] ?? const [])
          .map(ProductCode.fromRemoteMap)
          .toList();
      final existingPaths = {
        for (final image in existing?.images ?? const <ProductImageData>[])
          image.id: image.localPath,
      };
      final images =
          (imageMapsByProduct[productId] ?? const [])
              .map(
                (imageMap) => ProductImageData.fromRemoteMap(
                  imageMap,
                  existingLocalPath: existingPaths[imageMap['id']],
                ),
              )
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      await _database.applyRemoteProduct(
        Product.fromRemoteMap(productMap, codes, images: images),
      );
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('MARKET_ACCESS_DENIED')) {
      return 'Marktnummer oder PIN ist falsch.';
    }
    if (text.contains('MARKET_PIN_DENIED')) {
      return 'PIN ist falsch.';
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
    _marketSession = session;
    _database.setActiveMarket(session?.marketId);
  }

  Future<void> _persistMarketSession(MarketSession session) async {
    _setMarketSession(session);
    await _database.saveMarketSession(session);
  }

  Future<void> _clearMarketSession() async {
    _setMarketSession(null);
    await _database.clearMarketSession();
  }
}
