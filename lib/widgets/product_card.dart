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
    return SizedBox(
      height: 120.0,
      child: Dismissible(
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black38,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.0),
            child: Row(
              children: [
                SizedBox(
                  width: 140.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(
                        color: Colors.black26,
                      )),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 1.0),
                      child: GestureDetector(
                        onTap: product.images.isEmpty ? null : onOpenImages,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(11.0), bottomLeft: Radius.circular(11.0)),
                              child: ProductImage(product: product, imageHeight: 120.0, imageWidth: 140.0, iconSize: 120,),
                            ),
                            if (product.isOrganic || product.isPromotion)
                              Positioned(
                                left: 6,
                                top: 6,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (product.isOrganic)
                                      _ProductBadge(
                                        label: 'BIO',
                                        icon: Icons.eco,
                                        background: Colors.green[900]!,
                                      ),
                                    if (product.isPromotion)
                                      const _ProductBadge(
                                        label: 'AKTION',
                                        icon: Icons.local_offer,
                                        background: Colors.red,
                                      ),
                                  ],
                                ),
                              ),
                            if (product.images.length > 1)
                              Positioned(
                                right: 6,
                                bottom: 3,
                                child: Badge(
                                  label: Text('${product.images.length}'),
                                  backgroundColor: Colors.black54,
                                  child: const Icon(
                                    Icons.photo_library,
                                    size: 21,
                                    color: Colors.white60,
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 2,
                                        offset: Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: product.isPromotion
                        ? const Color(0xFFFFF0EA)
                        : product.isOrganic
                        ? const Color(0xFFF0F8EF)
                        : Colors.white,
                    borderRadius: BorderRadius.only(topRight: Radius.circular(12.0), bottomRight: Radius.circular(12.0)),
                    child: InkWell(
                      borderRadius: BorderRadius.only(topRight: Radius.circular(12.0), bottomRight: Radius.circular(12.0)),
                      onTap: code?.type.canShowBarcode == true
                          ? onShowCode
                          : null,
                      onLongPress: onOpenDetails,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 12.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Spacer(),
                                if (product.isPinned)
                                  Icon(
                                    Icons.push_pin,
                                    size: 18,
                                    color: Color(0xffcc071e),
                                    semanticLabel: 'Angepinnt',
                                  ),
                                GestureDetector(
                                  onTap: onOpenDetails,
                                  child: Icon(
                                      Icons.info_outline,
                                    size: 20.0,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    product.aliases.isEmpty
                                        ? product.category
                                        : '${product.category} · auch: ${product.aliases.join(', ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            if (code != null) _CodeButton(code: code, onPressed: onShowCode)
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black54, width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                  child: Row(
                                    children: [
                                      Text(
                                          "Produkt veraltet!",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          color: Colors.black54
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
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
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
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
    return Material(
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: canShow ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (code.type == ProductCodeType.cashierTile) ...[
                        Text(
                          code.displayValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ] else if (code.type == ProductCodeType.barcode) ...[
                        Text(
                          'Barcode: Bitte scannen!',
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
                      ] else ...[
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
                      ],
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
                if (code.type == ProductCodeType.cashierTile) ...[
                  const SizedBox(width: 7),
                  const Icon(Icons.dashboard_customize_outlined, size: 20),
                ],
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
