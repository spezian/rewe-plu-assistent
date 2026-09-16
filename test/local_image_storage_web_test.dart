@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/data/local_image_storage.dart';

void main() {
  const storage = LocalImageStorage();
  const firstImage = 'data:image/png;base64,AQID';
  const secondImage = 'data:image/png;base64,BAUG';

  test('verwendet für dieselbe Data-URI einen stabilen Bild-Cache-Key', () {
    final firstProvider = storage.providerFor(firstImage);
    final rebuiltProvider = storage.providerFor(firstImage);

    expect(firstProvider, isNotNull);
    expect(rebuiltProvider, equals(firstProvider));
    expect(rebuiltProvider.hashCode, firstProvider.hashCode);
  });

  test('unterscheidet verschiedene Data-URIs im Bild-Cache', () {
    expect(
      storage.providerFor(secondImage),
      isNot(storage.providerFor(firstImage)),
    );
  });

  test('lehnt Referenzen ab, die keine Bild-Data-URI sind', () {
    expect(storage.providerFor('https://example.test/image.png'), isNull);
    expect(storage.providerFor(null), isNull);
  });
}
