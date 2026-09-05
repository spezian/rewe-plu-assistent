import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
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
  bool get isAuthenticated => _sync.isAuthenticated;
  String? get currentUserEmail => _sync.currentUserEmail;

  Future<void> initialize() => _database.initialize();

  Future<List<Product>> getProducts() => _database.getProducts();

  Future<void> saveProduct(Product product) => _database.saveProduct(product);

  Future<void> deleteProduct(String productId) =>
      _database.deleteProduct(productId);

  Future<SyncReport> synchronize() => _sync.synchronize();

  Future<void> signIn({required String email, required String password}) =>
      _sync.signIn(email: email, password: password);

  Future<void> signOut() => _sync.signOut();

  Future<int> pendingCount() => _database.pendingCount();

  Future<String> importPickedImage(XFile pickedFile) =>
      _imageStorage.importPickedImage(pickedFile);

  Future<String> importImageFromUrl(String rawUrl) =>
      _imageStorage.importImageFromUrl(rawUrl);
}
