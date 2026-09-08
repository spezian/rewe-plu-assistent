import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';

class LocalImageStorage {
  const LocalImageStorage();

  static const _uuid = Uuid();

  Future<String> importPickedImage(XFile pickedFile) async {
    final extension = path.extension(pickedFile.path).isEmpty
        ? '.jpg'
        : path.extension(pickedFile.path).toLowerCase();
    final destination = await _newImagePath(extension);
    await File(pickedFile.path).copy(destination);
    return destination;
  }

  Future<String> importImageFromUrl(String rawUrl) async {
    final response = await _downloadImage(rawUrl);
    final extension = _extensionForMimeType(response.headers['content-type']);
    final destination = await _newImagePath(extension);
    await File(destination).writeAsBytes(response.bodyBytes, flush: true);
    return destination;
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

  Future<String> _newImagePath(String extension) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'product_images'));
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

String _extensionForMimeType(String? contentType) =>
    switch (_mimeType(contentType)) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      _ => '.jpg',
    };
