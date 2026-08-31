import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.product,
    this.size = 72,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final Product product;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final localPath = product.imagePath;
    final imageUrl = product.imageUrl;
    Widget child;
    if (localPath != null && File(localPath).existsSync()) {
      child = Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      child = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else {
      child = _fallback(context);
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: size, height: size, child: child),
    );
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
    return ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        icon,
        size: size * .46,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}
