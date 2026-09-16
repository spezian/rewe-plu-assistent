import 'package:material_ui/material_ui.dart';

import '../data/local_image_storage.dart';
import '../models/product.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.product,
    this.iconSize = 72,
    this.imageWidth,
    this.imageHeight,
    super.key,
  });

  final Product product;
  final double iconSize;
  final double? imageWidth;
  final double? imageHeight;
  static const _imageStorage = LocalImageStorage();

  @override
  Widget build(BuildContext context) {
    final primaryImage = product.primaryImage;
    Widget child;
    final localProvider =
        _imageStorage.providerFor(primaryImage?.localThumbnailPath) ??
        _imageStorage.providerFor(primaryImage?.localPath);
    if (localProvider != null) {
      child = Image(
        image: localProvider,
        fit: BoxFit.cover,
        width: imageWidth,
        height: imageHeight,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else {
      child = _networkImage(
        context,
        primaryImage?.remoteThumbnailUrl,
        fallbackUrl: primaryImage?.remoteUrl,
      );
    }
    return child;
  }

  Widget _networkImage(
    BuildContext context,
    String? imageUrl, {
    String? fallbackUrl,
  }) {
    final effectiveUrl = imageUrl?.isNotEmpty == true ? imageUrl! : fallbackUrl;
    if (effectiveUrl == null || effectiveUrl.isEmpty) {
      return _fallback(context);
    }
    return Image.network(
      effectiveUrl,
      fit: BoxFit.cover,
      width: imageWidth,
      height: imageHeight,
      errorBuilder: (_, _, _) {
        if (fallbackUrl != null &&
            fallbackUrl.isNotEmpty &&
            fallbackUrl != effectiveUrl) {
          return _networkImage(context, fallbackUrl);
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final icon = switch (product.category) {
      'Obst' => Icons.apple,
      'Gemüse' => Icons.eco,
      'Pilze' => Icons.park,
      'Schalenfrüchte' => Icons.spa,
      'Beschädigt' => Icons.broken_image,
      'Backwaren' => Icons.bakery_dining,
      'Alkohol' => Icons.wine_bar,
      'Mobilfunk' => Icons.phone_android,
      _ => Icons.shopping_basket,
    };
    return SizedBox(
      width: imageWidth,
      height: imageHeight,
      child: Icon(icon, size: iconSize * .46, color: Color(0xffcc071e)),
    );
  }
}
