import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'data/product_repository.dart';
import 'data/imported_product_image.dart';
import 'models/market_session.dart';
import 'models/product.dart';
import 'utils/product_sort.dart';

enum AppSyncState { localOnly, locked, idle, syncing, error }

class AppController extends ChangeNotifier {
  AppController(
    this.repository, {
    Stream<List<ConnectivityResult>>? connectivityChanges,
    this.liveSyncDebounce = const Duration(milliseconds: 500),
  }) : _connectivityChanges =
           connectivityChanges ?? Connectivity().onConnectivityChanged;

  final ProductRepository repository;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final Duration liveSyncDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _remoteChangesSubscription;
  Timer? _liveSyncTimer;
  bool _liveSyncRequested = false;

  List<Product> _products = const [];
  List<Product> get products => _products;

  bool isLoading = true;
  AppSyncState syncState = AppSyncState.idle;
  String? syncError;
  int pendingChanges = 0;

  bool get isSyncConfigured => repository.isSyncConfigured;
  bool get hasMarketAccess => repository.hasMarketAccess;
  bool get canEdit => repository.canEdit;
  MarketAccessLevel? get marketAccessLevel =>
      repository.marketSession?.accessLevel;

  Future<void> initialize() async {
    _remoteChangesSubscription = repository.remoteChanges.listen((_) {
      _scheduleLiveSync();
    });
    await repository.initialize();
    await _reload();
    isLoading = false;
    syncState = !isSyncConfigured
        ? AppSyncState.localOnly
        : hasMarketAccess
        ? AppSyncState.idle
        : AppSyncState.locked;
    notifyListeners();

    _connectivitySubscription = _connectivityChanges.listen((connections) {
      if (!connections.contains(ConnectivityResult.none)) {
        unawaited(syncNow());
      }
    });
    if (hasMarketAccess) unawaited(syncNow());
  }

  Product? productById(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> saveProduct(Product product) async {
    await repository.saveProduct(product);
    await _reload();
    notifyListeners();
    if (hasMarketAccess) unawaited(syncNow());
  }

  Future<void> deleteProduct(String productId) async {
    await repository.deleteProduct(productId);
    await _reload();
    notifyListeners();
    if (hasMarketAccess) unawaited(syncNow());
  }

  Future<void> togglePinned(Product product) async {
    await saveProduct(
      product.copyWith(isPinned: !product.isPinned, updatedAt: DateTime.now()),
    );
  }

  Future<void> reactivateCode(Product product, ProductCode selected) async {
    final now = DateTime.now();
    final codes = product.codes
        .map((code) {
          if (code.id == selected.id) {
            return code.copyWith(isActive: true, clearRetiredAt: true);
          }
          if (code.isActive) {
            return code.copyWith(isActive: false, retiredAt: now);
          }
          return code.copyWith(isActive: false);
        })
        .toList(growable: false);
    await saveProduct(product.copyWith(codes: codes, updatedAt: now));
  }

  Future<ImportedProductImage> importPickedImage(XFile image) =>
      repository.importPickedImage(image);

  Future<ImportedProductImage> importImageFromUrl(String url) =>
      repository.importImageFromUrl(url);

  Future<String?> cacheRemoteOriginal(ProductImageData image) =>
      repository.cacheRemoteOriginal(image);

  Future<void> enterMarket({required String marketNumber, String? pin}) async {
    await repository.enterMarket(marketNumber: marketNumber, pin: pin);
    syncState = AppSyncState.idle;
    syncError = null;
    await _reload();
    notifyListeners();
    await syncNow();
  }

  Future<void> upgradeToEditor(String pin) async {
    await repository.upgradeToEditor(pin);
    syncState = AppSyncState.idle;
    syncError = null;
    notifyListeners();
    await syncNow();
  }

  Future<void> leaveMarket() async {
    _cancelScheduledLiveSync();
    await repository.leaveMarket();
    _products = const [];
    pendingChanges = 0;
    syncState = AppSyncState.locked;
    syncError = null;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!isSyncConfigured || !hasMarketAccess) {
      if (isSyncConfigured) syncState = AppSyncState.locked;
      notifyListeners();
      return;
    }
    if (syncState == AppSyncState.syncing) return;
    syncState = AppSyncState.syncing;
    syncError = null;
    notifyListeners();
    final report = await repository.synchronize();
    pendingChanges = report.pendingCount;
    syncError = report.error;
    syncState = report.succeeded ? AppSyncState.idle : AppSyncState.error;
    await _reload();
    notifyListeners();
    if (_liveSyncRequested) _scheduleLiveSync();
  }

  void _scheduleLiveSync() {
    if (!isSyncConfigured || !hasMarketAccess) return;
    _liveSyncRequested = true;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer(liveSyncDebounce, _runScheduledLiveSync);
  }

  void _runScheduledLiveSync() {
    _liveSyncTimer = null;
    if (!_liveSyncRequested) return;
    if (!isSyncConfigured || !hasMarketAccess) {
      _liveSyncRequested = false;
      return;
    }
    if (syncState == AppSyncState.syncing) {
      _liveSyncTimer = Timer(liveSyncDebounce, _runScheduledLiveSync);
      return;
    }
    _liveSyncRequested = false;
    unawaited(syncNow());
  }

  void _cancelScheduledLiveSync() {
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
    _liveSyncRequested = false;
  }

  Future<void> _reload() async {
    _products = await repository.getProducts();
    _products = [..._products]..sort(compareProductsForOverview);
    pendingChanges = await repository.pendingCount();
  }

  @override
  void dispose() {
    _cancelScheduledLiveSync();
    _connectivitySubscription?.cancel();
    _remoteChangesSubscription?.cancel();
    unawaited(repository.dispose());
    super.dispose();
  }
}
