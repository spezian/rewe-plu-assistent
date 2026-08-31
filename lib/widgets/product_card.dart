import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    required this.onTogglePinned,
    required this.onOpenDetails,
    required this.onOpenImages,
    required this.onShowCode,
    super.key,
  });

  final Product product;
  final Future<void> Function() onTogglePinned;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenImages;
  final VoidCallback onShowCode;

  @override
  Widget build(BuildContext context) {
    final code = product.activeCode;
    return Dismissible(
      key: ValueKey('product-${product.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) async {
        unawaited(onTogglePinned());
        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        isPinned: product.isPinned,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        isPinned: product.isPinned,
      ),
      child: Card(
        color: product.isPromotion
            ? const Color(0xFFFFF0EA)
            : product.isOrganic
            ? const Color(0xFFF0F8EF)
            : null,
        child: InkWell(
          onTap: code?.type.canShowBarcode == true ? onShowCode : null,
          onLongPress: onOpenDetails,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Tooltip(
                  message: product.images.isEmpty
                      ? 'Kein Produktbild'
                      : 'Bilder im Vollbild',
                  child: InkWell(
                    onTap: product.images.isEmpty ? null : onOpenImages,
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        ProductImage(product: product, size: 68),
                        if (product.images.length > 1)
                          Positioned(
                            right: 3,
                            bottom: 3,
                            child: Badge(
                              label: Text('${product.images.length}'),
                              child: const Icon(
                                Icons.photo_library,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (product.isPinned)
                            Icon(
                              Icons.push_pin,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                              semanticLabel: 'Angepinnt',
                            ),
                          IconButton(
                            tooltip: 'Produktdetails',
                            onPressed: onOpenDetails,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.info_outline, size: 21),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.aliases.isEmpty
                            ? product.category
                            : '${product.category} · auch: ${product.aliases.first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (product.isOrganic || product.isPromotion) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (product.isOrganic)
                              const _ProductBadge(
                                label: 'BIO',
                                icon: Icons.eco,
                                background: Color(0xFF247A35),
                              ),
                            if (product.isPromotion)
                              const _ProductBadge(
                                label: 'AKTION',
                                icon: Icons.local_offer,
                                background: Color(0xFFD63B16),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 7),
                      if (code == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Produkt veraltet',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        )
                      else
                        _CodeButton(code: code, onPressed: onShowCode),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({
    required this.label,
    required this.icon,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeButton extends StatelessWidget {
  const _CodeButton({required this.code, required this.onPressed});

  final ProductCode code;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canShow = code.type.canShowBarcode;
    return Semantics(
      button: canShow,
      label: code.accessibilityLabel,
      hint: canShow ? 'Antippen, um den Barcode groß anzuzeigen' : null,
      child: Material(
        color: canShow
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: canShow ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              children: [
                if (code.type == ProductCodeType.cashierTile) ...[
                  const Icon(Icons.dashboard_customize_outlined, size: 20),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${code.type.label}: ${code.displayValue}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      if (code.secondaryDisplay case final secondary?)
                        Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                if (canShow) ...[
                  const SizedBox(width: 7),
                  const Icon(Icons.barcode_reader, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.alignment, required this.isPinned});

  final Alignment alignment;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
          const SizedBox(width: 8),
          Text(isPinned ? 'Lösen' : 'Anpinnen'),
        ],
      ),
    );
  }
}
