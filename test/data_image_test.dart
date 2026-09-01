import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/utils/data_image.dart';

void main() {
  test('encodes and decodes browser-persisted image data', () {
    final bytes = Uint8List.fromList([0, 1, 2, 250, 255]);

    final encoded = encodeDataImage(bytes, mimeType: 'image/png');
    final decoded = decodeDataImage(encoded);

    expect(encoded, startsWith('data:image/png;base64,'));
    expect(decoded?.mimeType, 'image/png');
    expect(decoded?.fileExtension, '.png');
    expect(decoded?.bytes, bytes);
  });

  test('rejects invalid or non-image data URLs', () {
    expect(decodeDataImage(null), isNull);
    expect(decodeDataImage('/tmp/photo.jpg'), isNull);
    expect(decodeDataImage('data:text/plain;base64,SGFsbG8='), isNull);
    expect(decodeDataImage('data:image/png;base64,%%%'), isNull);
  });
}
