import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/app_controller.dart';
import 'package:rewe_plu_assistent/data/product_repository.dart';
import 'package:rewe_plu_assistent/data/sync_service.dart';
import 'package:rewe_plu_assistent/models/market_session.dart';
import 'package:rewe_plu_assistent/models/product.dart';

void main() {
  test('bündelt schnelle Realtime-Ereignisse zu einem Sync', () async {
    final repository = _LiveSyncRepository();
    final controller = AppController(
      repository,
      connectivityChanges: const Stream<List<ConnectivityResult>>.empty(),
      liveSyncDebounce: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await _waitFor(() => repository.syncCalls == 1);

    repository
      ..emitRemoteChange()
      ..emitRemoteChange()
      ..emitRemoteChange();

    await _waitFor(() => repository.syncCalls == 2);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(repository.syncCalls, 2);
  });

  test('holt Ereignisse nach, die während eines Syncs eintreffen', () async {
    final repository = _LiveSyncRepository();
    final controller = AppController(
      repository,
      connectivityChanges: const Stream<List<ConnectivityResult>>.empty(),
      liveSyncDebounce: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await _waitFor(() => repository.syncCalls == 1);

    final blockedSync = repository.blockNextSync();
    repository.emitRemoteChange();
    await _waitFor(() => repository.syncCalls == 2);

    repository.emitRemoteChange();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(repository.syncCalls, 2);

    blockedSync.complete();
    await _waitFor(() => repository.syncCalls == 3);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final timeout = DateTime.now().add(const Duration(seconds: 1));
  while (!condition()) {
    if (DateTime.now().isAfter(timeout)) {
      fail('Zeitüberschreitung beim Warten auf den Live-Sync.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _LiveSyncRepository extends ProductRepository {
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Completer<void>? _blockedSync;
  int syncCalls = 0;

  @override
  bool get isSyncConfigured => true;

  @override
  bool get hasMarketAccess => true;

  @override
  bool get canEdit => true;

  @override
  MarketSession get marketSession => const MarketSession(
    marketId: 'market-a',
    accessLevel: MarketAccessLevel.editor,
  );

  @override
  Stream<void> get remoteChanges => _changes.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Product>> getProducts() async => const [];

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<SyncReport> synchronize() async {
    syncCalls += 1;
    final blockedSync = _blockedSync;
    _blockedSync = null;
    if (blockedSync != null) await blockedSync.future;
    return const SyncReport(pendingCount: 0);
  }

  Completer<void> blockNextSync() {
    return _blockedSync = Completer<void>();
  }

  void emitRemoteChange() => _changes.add(null);

  @override
  Future<void> dispose() => _changes.close();
}
