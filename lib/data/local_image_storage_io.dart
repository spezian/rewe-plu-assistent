import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import 'image_optimizer.dart';
import 'imported_product_image.dart';

class LocalImageStorage {
  const LocalImageStorage();

  static const _uuid = Uuid();

  Future<ImportedProductImage> importPickedImage(XFile pickedFile) async {
    return _storeOptimized(await pickedFile.readAsBytes());
  }

  Future<ImportedProductImage> importImageFromUrl(String rawUrl) async {
    final response = await _downloadImage(rawUrl);
    return _storeOptimized(response.bodyBytes);
  }

  Future<ImportedProductImage?> optimizeExistingImage(String reference) async {
    final file = File(reference);
    if (!await file.exists()) return null;
    return _storeOptimized(await file.readAsBytes());
  }

  ImageProvider<Object>? providerFor(String? reference) {
    if (reference == null || !File(reference).existsSync()) return null;
    return FileImage(File(reference));
  }

  Future<Uint8List?> readBytes(String reference) async {
    final file = File(reference);
    return await file.exists() ? file.readAsBytes() : null;
  }

  String extensionFor(String reference) {
    final extension = path.extension(reference).toLowerCase();
    return extension.isEmpty ? '.jpg' : extension;
  }

  Future<ImportedProductImage> _storeOptimized(Uint8List sourceBytes) async {
    final optimized = await optimizeProductImage(sourceBytes);
    final originalPath = await _newImagePath('.jpg');
    final thumbnailPath = await _newImagePath(
      '.jpg',
      directoryName: 'product_image_thumbnails',
    );
    await Future.wait([
      File(originalPath).writeAsBytes(optimized.original, flush: true),
      File(thumbnailPath).writeAsBytes(optimized.thumbnail, flush: true),
    ]);
    return ImportedProductImage(
      originalReference: originalPath,
      thumbnailReference: thumbnailPath,
    );
  }

  Future<String> _newImagePath(
    String extension, {
    String directoryName = 'product_images',
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, directoryName));
    await directory.create(recursive: true);
    return path.join(directory.path, '${_uuid.v4()}$extension');
  }
}

Future<http.Response> _downloadImage(String rawUrl) async {
  final uri = _validatedImageUri(rawUrl);
  final response = await http
      .get(uri, headers: {'User-Agent': userAgent})
      .timeout(const Duration(seconds: 15));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Bild konnte nicht geladen werden (${response.statusCode}).',
    );
  }
  if (!_mimeType(response.headers['content-type']).startsWith('image/')) {
    throw const FormatException('Die Adresse verweist nicht auf ein Bild.');
  }
  return response;
}

Uri _validatedImageUri(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      !uri.hasScheme ||
      !{'http', 'https'}.contains(uri.scheme)) {
    throw const FormatException(
      'Bitte eine gültige http(s)-Bildadresse eingeben.',
    );
  }
  return uri;
}

String _mimeType(String? contentType) =>
    (contentType ?? '').split(';').first.toLowerCase();
