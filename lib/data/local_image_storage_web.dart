import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class LocalImageStorage {
  const LocalImageStorage();

  Future<String> importPickedImage(XFile pickedFile) async {
    final bytes = await pickedFile.readAsBytes();
    final mimeType = pickedFile.mimeType ?? _mimeTypeForPath(pickedFile.name);
    return _dataUri(mimeType, bytes);
  }

  Future<String> importImageFromUrl(String rawUrl) async {
    final uri = _validatedImageUri(rawUrl);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Bild konnte nicht geladen werden (${response.statusCode}).',
      );
    }
    final mimeType = _mimeType(response.headers['content-type']);
    if (!mimeType.startsWith('image/')) {
      throw const FormatException('Die Adresse verweist nicht auf ein Bild.');
    }
    return _dataUri(mimeType, response.bodyBytes);
  }

  ImageProvider<Object>? providerFor(String? reference) {
    final bytes = reference == null ? null : _bytesFromDataUri(reference);
    return bytes == null ? null : MemoryImage(bytes);
  }

  Future<Uint8List?> readBytes(String reference) async =>
      _bytesFromDataUri(reference);

  String extensionFor(String reference) {
    final separator = reference.indexOf(';');
    final mimeType = separator < 0
        ? 'image/jpeg'
        : reference.substring(5, separator).toLowerCase();
    return switch (mimeType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      _ => '.jpg',
    };
  }
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

String _mimeTypeForPath(String fileName) =>
    switch (path.extension(fileName).toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };

String _dataUri(String mimeType, Uint8List bytes) =>
    'data:$mimeType;base64,${base64Encode(bytes)}';

Uint8List? _bytesFromDataUri(String reference) {
  if (!reference.startsWith('data:image/') || !reference.contains(';base64,')) {
    return null;
  }
  try {
    return base64Decode(reference.substring(reference.indexOf(',') + 1));
  } on FormatException {
    return null;
  }
}
