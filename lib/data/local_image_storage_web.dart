import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'image_optimizer.dart';
import 'imported_product_image.dart';

class LocalImageStorage {
  const LocalImageStorage();

  Future<ImportedProductImage> importPickedImage(XFile pickedFile) async {
    return _storeOptimized(await pickedFile.readAsBytes());
  }

  Future<ImportedProductImage> importImageFromUrl(String rawUrl) async {
    final response = await _downloadImage(rawUrl);
    return _storeOptimized(response.bodyBytes);
  }

  Future<String> cacheImageFromUrl(
    String rawUrl, {
    required bool thumbnail,
  }) async {
    final response = await _downloadImage(rawUrl);
    return _dataUri(
      _mimeType(response.headers['content-type']),
      response.bodyBytes,
    );
  }

  ImageProvider<Object>? providerFor(String? reference) {
    if (reference == null || !_isImageDataUri(reference)) return null;
    return _DataUriImageProvider(reference);
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

  Future<ImportedProductImage> _storeOptimized(Uint8List sourceBytes) async {
    final optimized = await optimizeProductImage(sourceBytes);
    return ImportedProductImage(
      originalReference: _dataUri('image/jpeg', optimized.original),
      thumbnailReference: _dataUri('image/jpeg', optimized.thumbnail),
    );
  }
}

Future<http.Response> _downloadImage(String rawUrl) async {
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

String _dataUri(String mimeType, Uint8List bytes) =>
    'data:$mimeType;base64,${base64Encode(bytes)}';

Uint8List? _bytesFromDataUri(String reference) {
  if (!_isImageDataUri(reference)) {
    return null;
  }
  try {
    return base64Decode(reference.substring(reference.indexOf(',') + 1));
  } on FormatException {
    return null;
  }
}

bool _isImageDataUri(String reference) =>
    reference.startsWith('data:image/') && reference.contains(';base64,');

/// Uses the data URI itself as the image-cache key.
///
/// Creating a new [MemoryImage] here would also create a new [Uint8List] on
/// every widget rebuild. [MemoryImage] compares that list by identity, so the
/// web image cache would treat the same stored image as a different image on
/// every keystroke-triggered rebuild. Besides repeatedly decoding the image,
/// that briefly replaces the current frame and makes images flicker.
@immutable
class _DataUriImageProvider extends ImageProvider<_DataUriImageProvider> {
  const _DataUriImageProvider(this.dataUri);

  final String dataUri;

  @override
  Future<_DataUriImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_DataUriImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _DataUriImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1,
      debugLabel: 'DataUriImage',
    );
  }

  Future<ui.Codec> _loadAsync(
    _DataUriImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = _bytesFromDataUri(key.dataUri);
    if (bytes == null) {
      throw const FormatException('Ungültige Bild-Data-URI.');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is _DataUriImageProvider && other.dataUri == dataUri;

  @override
  int get hashCode => dataUri.hashCode;
}
