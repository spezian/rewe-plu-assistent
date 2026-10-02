import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rewe_plu_assistent/data/local_database.dart';
import 'package:rewe_plu_assistent/data/local_image_storage.dart';
import 'package:rewe_plu_assistent/data/sync_service.dart';
import 'package:rewe_plu_assistent/models/market_session.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory directory;
  late _CountingDatabase db;
  late _TestClient client;
  late SyncService service;
  late _ImageStorage images;
  late List<Product> remoteProducts;
  late List<http.Request> requests;
  late MarketAccessLevel access;
  Future<http.Response?> Function(http.Request)? intercept;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync-performance-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = _CountingDatabase();
    await db.initialize();
    db.setActiveMarket('market-a');
    access = MarketAccessLevel.viewer;
    await db.saveMarketSession(
      MarketSession(marketId: 'market-a', accessLevel: access),
    );
    remoteProducts = [];
    requests = [];
    intercept = null;
    images = _ImageStorage();
    client = _TestClient(
      MockClient((request) async {
        requests.add(request);
        final overridden = await intercept?.call(request);
        if (overridden != null) return overridden;
        final table = request.url.pathSegments.last;
        Object? data;
        if (table == 'current_market_access') {
          data = {'market_id': 'market-a', 'access_level': access.name};
        } else if (request.method != 'GET') {
          data = [];
        } else if (table != 'cashier_plans') {
          final List<Map<String, Object?>> all = switch (table) {
            'products' => remoteProducts.map((p) => p.toRemoteMap()).toList(),
            'product_codes' =>
              remoteProducts
                  .expand((p) => p.codes)
                  .map((c) => c.toRemoteMap())
                  .toList(),
            'product_images' =>
              remoteProducts
                  .expand((p) => p.images)
                  .map((i) => i.toRemoteMap())
                  .toList(),
            _ => throw StateError('Unexpected request: ${request.url}'),
          };
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final limit = int.parse(
            request.url.queryParameters['limit'] ?? '500',
          );
          data = all.skip(offset).take(limit).toList();
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': 'test-user',
          'aud': 'authenticated',
          'is_anonymous': true,
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-09-01T00:00:00Z',
        },
      }),
    );
    service = SyncService(
      db,
      client,
      imageStorage: images,
      requestTimeout: const Duration(milliseconds: 200),
    );
  });
  tearDown(() async {
    await service.dispose();
    await client.dispose();
    await databaseFactory.deleteDatabase(
      '${directory.path}/rewe_plu_assistent.db',
    );
    await directory.delete(recursive: true);
  });

  test('offline startup restores market without any network request', () async {
    intercept = (_) => Completer<http.Response?>().future;
    await service.initialize().timeout(const Duration(seconds: 1));
    expect(service.hasMarketAccess, isTrue);
    expect(requests, isEmpty);
    final report = await service.synchronize();
    expect(report.succeeded, isFalse);
    expect(service.hasMarketAccess, isTrue);
    expect((await db.loadSavedMarketSession())?.marketId, 'market-a');
  });

  test(
    'parallel table reads and unchanged products cause no product writes',
    () async {
      remoteProducts = List.generate(100, (i) => product('p-$i'));
      await db.applyRemoteChanges(
        marketId: 'market-a',
        products: remoteProducts,
        deletedIds: [],
      );
      db.changedRows = 0;
      final tablesStarted = <String>{};
      final gate = Completer<void>();
      intercept = (request) async {
        final table = request.url.pathSegments.last;
        if (['products', 'product_codes', 'product_images'].contains(table)) {
          tablesStarted.add(table);
          if (tablesStarted.length == 3) gate.complete();
          await gate.future;
        }
        return null;
      };
      await service.initialize();
      final report = await service.synchronize();
      expect(report.error, isNull);
      expect(tablesStarted, hasLength(3));
      expect(db.changedRows, 0);
      expect(db.singleProductReads, 0);
      expect(db.snapshotReads, 1);
    },
  );

  test('pagination includes products beyond the first response page', () async {
    remoteProducts = List.generate(
      501,
      (i) => product('p-${i.toString().padLeft(4, '0')}'),
    );
    await service.initialize();
    expect((await service.synchronize()).error, isNull);
    expect(await db.getProducts(), hasLength(501));
    expect(
      requests.where((r) => r.url.path.endsWith('/products')),
      hasLength(2),
    );
  });

  test(
    'slow thumbnails do not delay data sync and refresh locally afterwards',
    () async {
      remoteProducts = [product('p1', withImage: true)];
      final download = Completer<String>();
      images.download = download.future;
      await service.initialize();
      final cached = service.localChanges.first;
      expect((await service.synchronize()).error, isNull);
      expect(download.isCompleted, isFalse);
      expect((await db.getProducts()).single.name, 'Produkt p1');
      download.complete('/cached/thumb.jpg');
      await cached.timeout(const Duration(seconds: 1));
      expect(
        (await db.getProduct('p1'))!.images.single.localThumbnailPath,
        '/cached/thumb.jpg',
      );
    },
  );

  test(
    'unchanged remote images are not uploaded again after a text edit',
    () async {
      access = MarketAccessLevel.editor;
      await db.saveMarketSession(
        MarketSession(marketId: 'market-a', accessLevel: access),
      );
      final saved = product('p1', withImage: true);
      final local = saved.copyWith(
        images: [
          saved.images.single.copyWith(
            localPath: '/original.jpg',
            localThumbnailPath: '/thumbnail.jpg',
          ),
        ],
      );
      await db.saveProduct(local);
      remoteProducts = [local];
      await service.initialize();
      expect((await service.synchronize()).error, isNull);
      expect(images.byteReads, 0);
      expect(requests.any((r) => r.url.path.contains('/storage/')), isFalse);
      expect(await db.pendingCount(), 0);
    },
  );

  test('bulk pull protects edits made after the remote snapshot', () async {
    final original = product('p1');
    await db.applyRemoteProduct(original);
    await db.saveProduct(original.copyWith(name: 'Lokaler Entwurf'));
    await db.applyRemoteChanges(
      marketId: 'market-a',
      products: [original.copyWith(name: 'Server')],
      deletedIds: ['p1'],
    );
    expect((await db.getProduct('p1'))!.name, 'Lokaler Entwurf');
    expect(await db.pendingCount(), 1);
  });

  test('late thumbnail cannot attach to a replaced remote image', () async {
    final original = product('p1', withImage: true);
    await db.applyRemoteProduct(original);
    final changed = original.copyWith(
      images: [
        original.images.single.copyWith(
          remoteThumbnailUrl: 'https://example.org/new.jpg',
        ),
      ],
    );
    await db.applyRemoteChanges(
      marketId: 'market-a',
      products: [changed],
      deletedIds: [],
    );
    await db.storeRemoteThumbnails('market-a', {
      original.images.single: '/old-thumbnail.jpg',
    });
    expect(
      (await db.getProduct('p1'))!.images.single.localThumbnailPath,
      isNull,
    );
  });

  test('bulk pull preserves thumbnails cached since its snapshot', () async {
    final original = product('p1', withImage: true);
    await db.applyRemoteProduct(original);
    await db.storeRemoteThumbnails('market-a', {
      original.images.single: '/cached-thumb.jpg',
    });
    await db.applyRemoteChanges(
      marketId: 'market-a',
      products: [original.copyWith(name: 'Neu')],
      deletedIds: [],
    );
    expect(
      (await db.getProduct('p1'))!.images.single.localThumbnailPath,
      '/cached-thumb.jpg',
    );
  });
}

Product product(String id, {bool withImage = false}) {
  final date = DateTime.utc(2026, 9, 1);
  return Product(
    id: id,
    name: 'Produkt $id',
    category: 'Obst',
    createdAt: date,
    updatedAt: date,
    codes: [
      ProductCode(
        id: 'code-$id',
        productId: id,
        type: ProductCodeType.plu,
        value: '4011',
        isActive: true,
        createdAt: date,
      ),
    ],
    images: withImage
        ? [
            ProductImageData(
              id: 'image-$id',
              productId: id,
              sortOrder: 0,
              createdAt: date,
              remoteUrl: 'https://example.org/$id.jpg',
              remoteThumbnailUrl: 'https://example.org/$id-thumb.jpg',
            ),
          ]
        : [],
  );
}

class _CountingDatabase extends LocalDatabase {
  int changedRows = 0;
  int singleProductReads = 0;
  int snapshotReads = 0;
  @override
  Future<void> applyRemoteChanges({
    required String marketId,
    required List<Product> products,
    required List<String> deletedIds,
  }) {
    changedRows += products.length + deletedIds.length;
    return super.applyRemoteChanges(
      marketId: marketId,
      products: products,
      deletedIds: deletedIds,
    );
  }

  @override
  Future<Product?> getProduct(String id) {
    singleProductReads++;
    return super.getProduct(id);
  }

  @override
  Future<List<Product>> getProducts() {
    snapshotReads++;
    return super.getProducts();
  }
}

class _ImageStorage extends LocalImageStorage {
  Future<String>? download;
  int byteReads = 0;
  @override
  Future<String> cacheImageFromUrl(String url, {required bool thumbnail}) =>
      download ?? Future.value('/cached/thumb.jpg');
  @override
  Future<bool> exists(String reference) async => true;
  @override
  Future<Uint8List?> readBytes(String reference) async {
    byteReads++;
    return Uint8List(1);
  }
}

class _TestClient extends SupabaseClient {
  _TestClient(http.Client client)
    : super(
        'https://example.test',
        'test-key',
        httpClient: client,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) => _QuietChannel(name, realtime);
  @override
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';
}

class _QuietChannel extends RealtimeChannel {
  _QuietChannel(super.topic, super.socket);
  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) => this;
}
