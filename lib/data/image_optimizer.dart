import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

const int productImageMaxDimension = 1920;
const int productThumbnailMaxDimension = 320;
const int productImageJpegQuality = 82;
const int productThumbnailJpegQuality = 68;

class OptimizedImageBytes {
  const OptimizedImageBytes({required this.original, required this.thumbnail});

  final Uint8List original;
  final Uint8List thumbnail;
}

Future<OptimizedImageBytes> optimizeProductImage(Uint8List sourceBytes) async {
  final result = await compute(_optimizeProductImage, sourceBytes);
  return OptimizedImageBytes(
    original: result.original,
    thumbnail: result.thumbnail,
  );
}

({Uint8List original, Uint8List thumbnail}) _optimizeProductImage(
  Uint8List sourceBytes,
) {
  final decoded = image.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('Das Bildformat wird nicht unterstützt.');
  }

  final firstFrame = image.Image.from(decoded.frames.first, noAnimation: true);
  final oriented = image.bakeOrientation(firstFrame);
  final resizedOriginal = _resizeToFit(oriented, productImageMaxDimension);
  final resizedThumbnail = _resizeToFit(
    resizedOriginal,
    productThumbnailMaxDimension,
  );

  return (
    original: image.encodeJpg(
      _flattenOnWhite(resizedOriginal),
      quality: productImageJpegQuality,
    ),
    thumbnail: image.encodeJpg(
      _flattenOnWhite(resizedThumbnail),
      quality: productThumbnailJpegQuality,
    ),
  );
}

image.Image _resizeToFit(image.Image source, int maxDimension) {
  if (source.width <= maxDimension && source.height <= maxDimension) {
    return image.Image.from(source, noAnimation: true);
  }
  if (source.width >= source.height) {
    return image.copyResize(
      source,
      width: maxDimension,
      interpolation: image.Interpolation.average,
    );
  }
  return image.copyResize(
    source,
    height: maxDimension,
    interpolation: image.Interpolation.average,
  );
}

image.Image _flattenOnWhite(image.Image source) {
  final flattened = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  )..clear(image.ColorRgb8(255, 255, 255));
  return image.compositeImage(flattened, source);
}
