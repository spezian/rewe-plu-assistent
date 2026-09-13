import 'package:flutter/material.dart';

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
    final localPath = product.imagePath;
    final imageUrl = product.imageUrl;
    Widget child;
    final localProvider = _imageStorage.providerFor(localPath);
    if (localProvider != null) {
      child = Image(
        image: localProvider,
        fit: BoxFit.cover,
        width: imageWidth,
        height: imageHeight,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      child = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: imageWidth,
        height: imageHeight,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else {
      child = _fallback(context);
    }
    return child;
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
