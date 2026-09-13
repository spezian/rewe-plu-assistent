import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
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

  bool get isSyncConfigured => _sync.isConfigured;
  bool get hasMarketAccess => _sync.hasMarketAccess;
  bool get canEdit => _sync.canEdit;
  MarketSession? get marketSession => _sync.marketSession;

  Future<void> initialize() async {
    await _database.initialize();
    await _sync.initialize();
    await _optimizeLegacyImages();
  }

  Future<List<Product>> getProducts() => _database.getProducts();

  Future<void> saveProduct(Product product) {
    _requireEditor();
    return _database.saveProduct(product);
  }

  Future<void> deleteProduct(String productId) {
    _requireEditor();
    return _database.deleteProduct(productId);
  }

  Future<SyncReport> synchronize() => _sync.synchronize();

  Future<void> enterMarket({required String marketNumber, String? pin}) =>
      _sync.enterMarket(marketNumber: marketNumber, pin: pin);

  Future<void> upgradeToEditor(String pin) => _sync.upgradeToEditor(pin);

  Future<void> leaveMarket() => _sync.leaveMarket();

  Future<int> pendingCount() => _database.pendingCount();

  Future<ImportedProductImage> importPickedImage(XFile pickedFile) =>
      _imageStorage.importPickedImage(pickedFile);

  Future<ImportedProductImage> importImageFromUrl(String rawUrl) =>
      _imageStorage.importImageFromUrl(rawUrl);

  Future<void> _optimizeLegacyImages() async {
    final products = await _database.getProducts();
    for (final product in products) {
      var changed = false;
      final images = <ProductImageData>[];
      for (final image in product.images) {
        final localPath = image.localPath;
        if (localPath == null || image.localThumbnailPath != null) {
          images.add(image);
          continue;
        }
        try {
          final optimized = await _imageStorage.optimizeExistingImage(
            localPath,
          );
          if (optimized == null) {
            images.add(image);
            continue;
          }
          images.add(
            image.copyWith(
              localPath: optimized.originalReference,
              localThumbnailPath: optimized.thumbnailReference,
            ),
          );
          changed = true;
        } catch (_) {
          // Ein nicht unterstütztes Altbild darf den App-Start nicht blockieren.
          images.add(image);
        }
      }
      if (changed) {
        final enqueue = _sync.canEdit;
        await _database.saveProduct(
          product.copyWith(
            images: images,
            updatedAt: enqueue ? DateTime.now() : product.updatedAt,
          ),
          enqueue: enqueue,
        );
      }
    }
  }

  void _requireEditor() {
    if (!canEdit) {
      throw StateError('Dieser Marktzugang ist schreibgeschützt.');
    }
  }
}
