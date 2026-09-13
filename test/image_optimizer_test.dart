import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:rewe_plu_assistent/data/image_optimizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'erzeugt ein optimiertes Original und ein kleines JPEG-Thumbnail',
    () async {
      final source = image.Image(width: 2400, height: 1200, numChannels: 4);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 210);
        }
      }

      final optimized = await optimizeProductImage(image.encodePng(source));
      final original = image.decodeJpg(optimized.original);
      final thumbnail = image.decodeJpg(optimized.thumbnail);

      expect(original, isNotNull);
      expect(original!.width, productImageMaxDimension);
      expect(original.height, 960);
      expect(thumbnail, isNotNull);
      expect(thumbnail!.width, productThumbnailMaxDimension);
      expect(thumbnail.height, 160);
      expect(optimized.original.take(2), [0xff, 0xd8]);
      expect(optimized.thumbnail.take(2), [0xff, 0xd8]);
      expect(optimized.thumbnail.length, lessThan(optimized.original.length));
    },
  );
}
