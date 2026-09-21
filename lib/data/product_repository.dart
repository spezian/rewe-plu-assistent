import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/cashier_plan.dart';
import '../models/market_session.dart';
import 'local_image_storage.dart';
import 'local_database.dart';
import 'sync_service.dart';

class ProductRepository {
  ProductRepository({this.supabaseClient}) : _database = LocalDatabase();

  final LocalDatabase _database;
  final LocalImageStorage _imageStorage = const LocalImageStorage();
  final SupabaseClient? supabaseClient;
  late final SyncService _sync = SyncService(_database, supabaseClient);

  bool _hasAcknowledgedAppNotice = false;
  bool get hasAcknowledgedAppNotice => _hasAcknowledgedAppNotice;

  bool get isSyncConfigured => _sync.isConfigured;
  bool get hasMarketAccess => _sync.hasMarketAccess;
  bool get canEdit => _sync.canEdit;
  MarketSession? get marketSession => _sync.marketSession;
  Stream<void> get remoteChanges => _sync.remoteChanges;

  Future<void> initialize() async {
    await _database.initialize();
    _hasAcknowledgedAppNotice = await _database.hasAcknowledgedAppNotice();
    await _sync.initialize();
  }

  Future<void> acknowledgeAppNotice() async {
    await _database.acknowledgeAppNotice();
    _hasAcknowledgedAppNotice = true;
  }

  Future<List<Product>> getProducts() => _database.getProducts();

  Future<CashierPlan> getCashierPlan() => _database.getCashierPlan();

  Future<void> saveCashierPlanPatch(Map<String, dynamic> patch) {
    _requireEditor();
    return _database.saveCashierPlanPatch(patch);
  }

  Future<void> saveProduct(Product product) {
    _requireEditor();
    return _database.saveProduct(product);
  }

  Future<void> deleteProduct(String productId) {
    _requireEditor();
    return _database.deleteProduct(productId);
  }

  Future<SyncReport> synchronize({SyncProgressCallback? onProgress}) =>
      _sync.synchronize(onProgress: onProgress);

  Future<void> enterMarket({required String marketNumber, String? pin}) =>
      _sync.enterMarket(marketNumber: marketNumber, pin: pin);

  Future<void> upgradeToEditor(String pin) => _sync.upgradeToEditor(pin);

  Future<void> leaveMarket() => _sync.leaveMarket();

  Future<int> pendingCount() => _database.pendingCount();

  Future<void> dispose() => _sync.dispose();

  Future<ImportedProductImage> importPickedImage(XFile pickedFile) =>
      _imageStorage.importPickedImage(pickedFile);

  Future<ImportedProductImage> importImageFromUrl(String rawUrl) =>
      _imageStorage.importImageFromUrl(rawUrl);

  Future<String?> cacheRemoteOriginal(ProductImageData image) async {
    final storedPath = await _database.getLocalOriginalImagePath(image.id);
    for (final existingPath in [image.localPath, storedPath]) {
      if (existingPath != null &&
          await _imageStorage.readBytes(existingPath) != null) {
        return existingPath;
      }
    }
    final remoteUrl = image.remoteUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) return null;
    final localPath = await _imageStorage.cacheImageFromUrl(
      remoteUrl,
      thumbnail: false,
    );
    await _database.updateLocalImageCache(image.id, originalPath: localPath);
    return localPath;
  }

  void _requireEditor() {
    if (!canEdit) {
      throw StateError('Dieser Marktzugang ist schreibgeschützt.');
    }
  }
}
