import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../utils/data_image.dart';
import 'local_database.dart';
import 'sync_service.dart';

class ProductRepository {
  ProductRepository({this.supabaseClient}) : _database = LocalDatabase();

  final LocalDatabase _database;
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

  Future<String> importPickedImage(XFile pickedFile) async {
    return encodeDataImage(
      await pickedFile.readAsBytes(),
      mimeType: pickedFile.mimeType ?? _mimeTypeForName(pickedFile.name),
    );
  }

  Future<String> importImageFromUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const FormatException(
        'Bitte eine gültige http(s)-Bildadresse eingeben.',
      );
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Bild konnte nicht geladen werden (${response.statusCode}).',
      );
    }
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.startsWith('image/')) {
      throw const FormatException('Die Adresse verweist nicht auf ein Bild.');
    }
    return encodeDataImage(
      response.bodyBytes,
      mimeType: contentType.split(';').first,
    );
  }

  String? _mimeTypeForName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.gif')) return 'image/gif';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return null;
  }
}
