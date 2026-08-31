import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import 'local_database.dart';
import 'sync_service.dart';

class ProductRepository {
  ProductRepository({this.supabaseClient}) : _database = LocalDatabase();

  final LocalDatabase _database;
  final SupabaseClient? supabaseClient;
  late final SyncService _sync = SyncService(_database, supabaseClient);
  static const _uuid = Uuid();

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
    final extension = path.extension(pickedFile.path).isEmpty
        ? '.jpg'
        : path.extension(pickedFile.path).toLowerCase();
    final destination = await _newImagePath(extension);
    await File(pickedFile.path).copy(destination);
    return destination;
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
      throw HttpException(
        'Bild konnte nicht geladen werden (${response.statusCode}).',
      );
    }
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.startsWith('image/')) {
      throw const FormatException('Die Adresse verweist nicht auf ein Bild.');
    }
    final extension = switch (contentType.split(';').first) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '.jpg',
    };
    final destination = await _newImagePath(extension);
    await File(destination).writeAsBytes(response.bodyBytes, flush: true);
    return destination;
  }

  Future<String> _newImagePath(String extension) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'product_images'));
    await directory.create(recursive: true);
    return path.join(directory.path, '${_uuid.v4()}$extension');
  }
}
