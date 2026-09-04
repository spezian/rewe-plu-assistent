import 'dart:io';

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final localPath = product.imagePath;
    final imageUrl = product.imageUrl;
    Widget child;
    if (localPath != null && File(localPath).existsSync()) {
      child = Image.file(
        File(localPath),
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
      'Backwaren' => Icons.bakery_dining,
      'Getränke' => Icons.local_drink,
      'Molkereiprodukte' => Icons.breakfast_dining,
      'Fleisch & Wurst' => Icons.lunch_dining,
      'Tiefkühl' => Icons.ac_unit,
      'Süßwaren' => Icons.cake,
      'Haushalt' => Icons.cleaning_services,
      _ => Icons.shopping_basket,
    };
    return SizedBox(
      width: imageWidth,
      height: imageHeight,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          icon,
          size: iconSize * .46,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
