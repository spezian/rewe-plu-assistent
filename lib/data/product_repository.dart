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

  Future<String> importPickedImage(XFile pickedFile) =>
      _imageStorage.importPickedImage(pickedFile);

  Future<String> importImageFromUrl(String rawUrl) =>
      _imageStorage.importImageFromUrl(rawUrl);

  void _requireEditor() {
    if (!canEdit) {
      throw StateError('Dieser Marktzugang ist schreibgeschützt.');
    }
  }
}
