import 'package:flutter/material.dart';
import 'package:rewe_plu_assistent/core/app_constants.dart';

import '../app_scope.dart';
import '../models/product.dart';
import '../utils/product_search.dart';
import '../widgets/product_badge.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import 'barcode_screen.dart';
import 'product_detail_screen.dart';
import 'product_gallery_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({required this.isActive, super.key});

  final bool isActive;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (oldWidget.isActive && !widget.isActive) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = AppScope.of(context);
    final result = searchProducts(controller.products, _query);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
          child: TextField(
            controller: _queryController,
            focusNode: _focusNode,
            autofocus: false,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Produkt, PLU oder Barcode',
              hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: Colors.grey[600],
                  ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              fillColor: Colors.grey[200]!,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Suche löschen',
                      onPressed: () {
                        _queryController.clear();
                        setState(() => _query = '');
                        _focusNode.requestFocus();
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        if (_query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.spellcheck, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kleine Tippfehler werden erkannt. Prüfe trotzdem Name und Code.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child:
              result.currentProducts.isEmpty &&
                  result.obsoleteProducts.isEmpty &&
                  result.retiredCodes.isEmpty
              ? const _NoSearchResults()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  children: [
                    if (result.currentProducts.isNotEmpty) ...[
                      _SectionHeader(
                        title: _query.isEmpty
                            ? 'Alle aktuellen Codes'
                            : 'Aktuell',
                        count: result.currentProducts.length,
                      ),
                      for (final product in result.currentProducts) ...[
                        ProductCard(
                          product: product,
                          onTogglePinned: () =>
                              controller.togglePinned(product),
                          onOpenDetails: () => _openDetails(context, product),
                          onOpenImages: () => _openImages(context, product),
                          onShowCode: () => _showActiveCode(context, product),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (result.obsoleteProducts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SectionHeader(
                        title: 'Veraltete Produkte',
                        count: result.obsoleteProducts.length,
                        warning: true,
                      ),
                      for (final product in result.obsoleteProducts) ...[
                        _ObsoleteProductCard(
                          product: product,
                          onOpenDetails: () => _openDetails(context, product),
                          onOpenImages: () => _openImages(context, product),
                          onShowCode: (code) => _showRetiredCode(
                            context,
                            RetiredCodeHit(product: product, code: code),
                          ),
                          onReactivate: (code) async {
                            await controller.reactivateCode(product, code);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${code.displayValue} ist wieder aktuell.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (result.retiredCodes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SectionHeader(
                        title: 'Veraltete Codes',
                        count: result.retiredCodes.length,
                        warning: true,
                      ),
                      for (final hit in result.retiredCodes) ...[
                        _RetiredCodeCard(
                          hit: hit,
                          onOpenDetails: () =>
                              _openDetails(context, hit.product),
                          onShowCode: () => _showRetiredCode(context, hit),
                          onReactivate: () async {
                            await controller.reactivateCode(
                              hit.product,
                              hit.code,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${hit.code.displayValue} ist jetzt der aktuelle Code.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  void _openDetails(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
  }

  void _openImages(BuildContext context, Product product) {
    if (product.images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProductGalleryScreen(title: product.name, images: product.images),
      ),
    );
  }

  void _showActiveCode(BuildContext context, Product product) {
    final code = product.activeCode;
    if (code == null || !code.type.canShowBarcode) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BarcodeScreen(product: product, code: code),
      ),
    );
  }

  void _showRetiredCode(BuildContext context, RetiredCodeHit hit) {
    if (!hit.code.type.canShowBarcode) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BarcodeScreen(
          product: hit.product,
          code: hit.code,
          isObsolete: true,
        ),
      ),
    );
  }
}

class _ObsoleteProductCard extends StatelessWidget {
  const _ObsoleteProductCard({
    required this.product,
    required this.onOpenDetails,
    required this.onOpenImages,
    required this.onShowCode,
    required this.onReactivate,
  });

  final Product product;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenImages;
  final ValueChanged<ProductCode> onShowCode;
  final Future<void> Function(ProductCode) onReactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black38, width: 1),
      ),
      child: InkWell(
        onLongPress: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8.0,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: product.images.isEmpty ? null : onOpenImages,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(12.0)
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: ProductImage(product: product, iconSize: 48, imageHeight: 48, imageWidth: 48,)
                        )
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (product.aliases.isNotEmpty)
                          Text(
                            'Auch: ${product.aliases.join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            ProductBadge(
                              label: product.category,
                              icon: Icons.category_outlined,
                              background: Colors.grey,
                            ),
                            if (product.isOrganic)
                              ProductBadge.bio(),
                            if (product.isPromotion)
                              ProductBadge.sale(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onOpenDetails,
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
              for (final code in product.retiredCodes)
                ListTile(
                  dense: true,
                  tileColor: reweTealContainer,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(
                      color: reweTeal,
                      width: 1.0,
                    )
                  ),
                  textColor: reweOnTeal,
                  onTap: code.type.canShowBarcode
                      ? () => onShowCode(code)
                      : null,
                  title: Text(
                    '${code.type.label}: ${code.displayValue}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: reweOnTeal,
                      decorationThickness: 2,
                    ),
                  ),
                  subtitle:
                      code.secondaryDisplay != null || code.note.isNotEmpty
                      ? Text(
                          [
                            ?code.secondaryDisplay,
                            if (code.note.isNotEmpty) code.note,
                          ].join(' · '),
                        )
                      : null,
                  trailing: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: reweTeal,
                      foregroundColor: reweOnTeal,
                      visualDensity: VisualDensity.compact
                    ),
                    tooltip: 'Diesen Code reaktivieren',
                    onPressed: () => onReactivate(code),
                    icon: const Icon(Icons.restore),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.warning = false,
  });

  final String title;
  final int count;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 5, 4, 8),
      child: Row(
        children: [
          if (warning) ...[
            Icon(
              Icons.history,
              size: 20,
              color: reweRed,
            ),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text('$count'),
        ],
      ),
    );
  }
}

class _RetiredCodeCard extends StatelessWidget {
  const _RetiredCodeCard({
    required this.hit,
    required this.onOpenDetails,
    required this.onShowCode,
    required this.onReactivate,
  });

  final RetiredCodeHit hit;
  final VoidCallback onOpenDetails;
  final VoidCallback onShowCode;
  final Future<void> Function() onReactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black38, width: 1),
      ),
      child: InkWell(
        onTap: onShowCode,
        onLongPress: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 8.0,
                      children: [
                        Flexible(
                          child: Text(
                            hit.product.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (hit.product.isOrganic)
                          ProductBadge.bio(),
                        if (hit.product.isPromotion)
                          ProductBadge.sale(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: hit.code.type.canShowBarcode ? onShowCode : null,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          border: BoxBorder.all(
                            color: reweTeal,
                            width: 1.0
                          ),
                          color: reweTealContainer
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${hit.code.type.label}: ${hit.code.displayValue}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.lineThrough,
                                  color: reweOnTeal,
                                  decorationThickness: 2.0,
                                  decorationColor: reweOnTeal,
                                ),
                              ),
                              if (hit.code.type.canShowBarcode) ...[
                                const SizedBox(width: 7),
                                const Icon(Icons.barcode_reader, size: 19, color: reweOnTeal,),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hit.code.note.isNotEmpty)
                      Text(
                        hit.code.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (hit.code.secondaryDisplay case final secondary?)
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
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                    backgroundColor: reweTealContainer,
                    foregroundColor: reweOnTeal,
                ),
                tooltip: 'Diesen Code reaktivieren',
                onPressed: onReactivate,
                icon: const Icon(Icons.restore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 52,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Kein eindeutiger Treffer',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Versuche einen kürzeren Namen oder gib den Code direkt ein.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
