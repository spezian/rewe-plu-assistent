import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:rewe_plu_assistent/core/app_constants.dart';
import 'package:rewe_plu_assistent/widgets/product_badge.dart';

import '../models/product.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    this.onTogglePinned,
    required this.onOpenDetails,
    required this.onOpenImages,
    required this.onShowCode,
    super.key,
  });

  final Product product;
  final Future<void> Function()? onTogglePinned;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenImages;
  final VoidCallback onShowCode;

  @override
  Widget build(BuildContext context) {
    final code = product.activeCode;
    return Dismissible(
      key: ValueKey('product-${product.id}'),
      direction: onTogglePinned == null
          ? DismissDirection.none
          : DismissDirection.horizontal,
      confirmDismiss: (_) async {
        final togglePinned = onTogglePinned;
        if (togglePinned != null) unawaited(togglePinned());
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black38),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.0),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(140.0),
                1: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: [
                TableRow(
                  children: [
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.fill,
                      child: SizedBox(
                        width: 140.0,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.black26),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 1.0),
                            child: Tooltip(
                              message: 'Bilder im Vollbild',
                              child: GestureDetector(
                                onTap: product.images.isEmpty
                                    ? null
                                    : onOpenImages,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(11.0),
                                        bottomLeft: Radius.circular(11.0),
                                      ),
                                      child: ProductImage(
                                        product: product,
                                        imageWidth: double.infinity,
                                        imageHeight: double.infinity,
                                        iconSize: 120,
                                      ),
                                    ),
                                    if (product.isOrganic ||
                                        product.isPromotion)
                                      Positioned(
                                        left: 6,
                                        top: 6,
                                        right: 6,
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (product.isOrganic)
                                              ProductBadge.bio(),
                                            if (product.isPromotion)
                                              ProductBadge.sale(),
                                          ],
                                        ),
                                      ),
                                    if (product.images.length > 1)
                                      Positioned(
                                        right: 6,
                                        bottom: 3,
                                        child: Badge(
                                          label: Text(
                                            '${product.images.length}',
                                          ),
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
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 118.0),
                      child: Material(
                        color: product.isPromotion
                            ? const Color(0xFFFFF0EA)
                            : product.isOrganic
                            ? const Color(0xFFF0F8EF)
                            : Colors.white,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12.0),
                          bottomRight: Radius.circular(12.0),
                        ),
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12.0),
                            bottomRight: Radius.circular(12.0),
                          ),
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
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            product.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        if (product.isPinned)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 1.0),
                                            child: Icon(
                                              Icons.push_pin,
                                              size: 18,
                                              color: Color(0xffcc071e),
                                              semanticLabel: 'Angepinnt',
                                            ),
                                          ),
                                        Tooltip(
                                          message: 'Produktdetails',
                                          child: GestureDetector(
                                            onTap: onOpenDetails,
                                            child: const Icon(
                                              Icons.info_outline,
                                              size: 20.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      product.aliases.isEmpty
                                          ? product.category
                                          : '${product.category} · auch: ${product.aliases.join(', ')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: code != null
                                      ? _CodeButton(
                                          code: code,
                                          onPressed: onShowCode,
                                        )
                                      : DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.black54,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 7,
                                            ),
                                            child: Text(
                                              'Produkt veraltet!',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      key: const ValueKey('product-code-button'),
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
                          '${code.type.productListLabel}: ${code.displayValue}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ] else if (code.type == ProductCodeType.info) ...[
                        Text(
                          code.displayValue,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ] else if (code.type == ProductCodeType.barcode) ...[
                        Text(
                          'Barcode: Bitte scannen!',
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
        color: reweTealContainer,
        borderRadius: BorderRadius.circular(12),
        border: BoxBorder.all(color: reweTeal, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            color: reweDarkTeal,
          ),
          const SizedBox(width: 8),
          Text(
            isPinned ? 'Lösen' : 'Anpinnen',
            style: Theme.of(context).textTheme.labelLarge!
                .copyWith(color: reweDarkTeal),
          ),
        ],
      ),
    );
  }
}
