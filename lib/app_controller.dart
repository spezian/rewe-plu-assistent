import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'data/product_repository.dart';
import 'models/product.dart';

enum AppSyncState { localOnly, locked, idle, syncing, error }

class AppController extends ChangeNotifier {
  AppController(this.repository);

  final ProductRepository repository;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<Product> _products = const [];
  List<Product> get products => _products;

  bool isLoading = true;
  AppSyncState syncState = AppSyncState.idle;
  String? syncError;
  int pendingChanges = 0;

  bool get isSyncConfigured => repository.isSyncConfigured;
  bool get isAuthenticated => repository.isAuthenticated;
  String? get currentUserEmail => repository.currentUserEmail;

  Future<void> initialize() async {
    await repository.initialize();
    await _reload();
    isLoading = false;
    syncState = !isSyncConfigured
        ? AppSyncState.localOnly
        : isAuthenticated
        ? AppSyncState.idle
        : AppSyncState.locked;
    notifyListeners();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      connections,
    ) {
      if (!connections.contains(ConnectivityResult.none)) {
        unawaited(syncNow());
      }
    });
    if (isAuthenticated) unawaited(syncNow());
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
    if (isAuthenticated) unawaited(syncNow());
  }

  Future<void> deleteProduct(String productId) async {
    await repository.deleteProduct(productId);
    await _reload();
    notifyListeners();
    if (isAuthenticated) unawaited(syncNow());
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

  Future<String> importPickedImage(XFile image) =>
      repository.importPickedImage(image);

  Future<String> importImageFromUrl(String url) =>
      repository.importImageFromUrl(url);

  Future<void> signIn({required String email, required String password}) async {
    await repository.signIn(email: email, password: password);
    syncState = AppSyncState.idle;
    syncError = null;
    notifyListeners();
    await syncNow();
  }

  Future<void> signOut() async {
    await repository.signOut();
    syncState = AppSyncState.locked;
    syncError = null;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!isSyncConfigured || !isAuthenticated) {
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
  }

  Future<void> _reload() async {
    _products = await repository.getProducts();
    _products = [..._products]
      ..sort((a, b) {
        if (a.isObsolete != b.isObsolete) return a.isObsolete ? 1 : -1;
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final categoryOrder = a.category.compareTo(b.category);
        if (categoryOrder != 0) return categoryOrder;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    pendingChanges = await repository.pendingCount();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
