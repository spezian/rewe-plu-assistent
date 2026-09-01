import 'dart:convert';
import 'dart:typed_data';

class DataImage {
  const DataImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  String get fileExtension => switch (mimeType) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    _ => '.jpg',
  };
}

String encodeDataImage(Uint8List bytes, {String? mimeType}) {
  final normalizedMimeType = mimeType?.startsWith('image/') == true
      ? mimeType!
      : 'image/jpeg';
  return 'data:$normalizedMimeType;base64,${base64Encode(bytes)}';
}

DataImage? decodeDataImage(String? value) {
  if (value == null || !value.startsWith('data:image/')) return null;
  final separator = value.indexOf(',');
  if (separator < 0) return null;
  final metadata = value.substring(5, separator);
  if (!metadata.endsWith(';base64')) return null;

  try {
    return DataImage(
      bytes: base64Decode(value.substring(separator + 1)),
      mimeType: metadata.substring(0, metadata.length - ';base64'.length),
    );
  } on FormatException {
    return null;
  }
}
