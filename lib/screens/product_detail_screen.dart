import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/product.dart';
import '../widgets/product_image.dart';
import 'barcode_screen.dart';
import 'product_form_screen.dart';
import 'product_gallery_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final product = controller.productById(productId);
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Produkt wurde entfernt.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produktdetails'),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductFormScreen(product: product),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete(context, product);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Produkt löschen'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: product.images.isEmpty
                        ? null
                        : () => _openGallery(context, product, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ProductImage(
                        product: product,
                        iconSize: 104,
                        imageWidth: 104,
                        imageHeight: 104,

                      ),
                    ),
                  ),
                  if (product.images.length > 1)
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Badge(
                        label: Text('${product.images.length}'),
                        child: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      avatar: const Icon(Icons.category_outlined, size: 18),
                      label: Text(product.category),
                    ),
                    if (product.isOrganic || product.isPromotion)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (product.isOrganic)
                            const Chip(
                              avatar: Icon(Icons.eco, size: 17),
                              label: Text(
                                'BIO',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              backgroundColor: Color(0xFFCDECCF),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (product.isPromotion)
                            const Chip(
                              avatar: Icon(Icons.local_offer, size: 17),
                              label: Text(
                                'AKTION',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              backgroundColor: Color(0xFFFFD8CC),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    if (product.isPinned)
                      const Row(
                        children: [
                          Icon(Icons.push_pin, size: 17),
                          SizedBox(width: 5),
                          Text('Angepinnt'),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (product.aliases.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                for (final alias in product.aliases)
                  Chip(
                    avatar: const Icon(Icons.alternate_email, size: 16),
                    label: Text(alias),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (product.images.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: product.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => InkWell(
                  onTap: () => _openGallery(context, product, index),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 70,
                      child: _ProductImageThumbnail(
                        image: product.images[index],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(product.description),
          ],
          const SizedBox(height: 24),
          Text(
            'Aktueller Code',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (product.activeCode case final activeCode?)
            _CurrentCodeCard(product: product, code: activeCode)
          else
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dieses Produkt ist vollständig veraltet. Unten kann '
                        'ein Code reaktiviert werden.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Code-Verlauf',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text('${product.retiredCodes.length} veraltet'),
            ],
          ),
          const SizedBox(height: 8),
          if (product.retiredCodes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Noch keine veralteten Codes.'),
              ),
            )
          else
            for (final code in product.retiredCodes) ...[
              _HistoryCodeCard(product: product, code: code),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 18),
          Text(
            'Zuletzt geändert: ${_formatDate(product.updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${product.name} löschen?'),
        content: const Text(
          'Das Produkt und sein Code-Verlauf werden entfernt. Eine noch nicht '
          'synchronisierte Löschung wird später automatisch übertragen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppScope.of(context).deleteProduct(product.id);
    if (context.mounted) Navigator.pop(context);
  }

  void _openGallery(BuildContext context, Product product, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductGalleryScreen(
          title: product.name,
          images: product.images,
          initialIndex: index,
        ),
      ),
    );
  }
}

class _ProductImageThumbnail extends StatelessWidget {
  const _ProductImageThumbnail({required this.image});

  final ProductImageData image;

  @override
  Widget build(BuildContext context) {
    final product = Product(
      id: image.productId,
      name: '',
      category: '',
      createdAt: image.createdAt,
      updatedAt: image.createdAt,
      codes: const [],
      images: [image],
    );
    return ProductImage(
      product: product,);
  }
}

class _CurrentCodeCard extends StatelessWidget {
  const _CurrentCodeCard({required this.product, required this.code});

  final Product product;
  final ProductCode code;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        onTap: code.type.canShowBarcode
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BarcodeScreen(product: product, code: code),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(code.type.label),
                    const SizedBox(height: 3),
                    Text(
                      code.displayValue,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (code.secondaryDisplay case final secondary?)
                      Text(
                        secondary,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    if (code.note.isNotEmpty) Text(code.note),
                  ],
                ),
              ),
              if (code.type.canShowBarcode)
                const Icon(Icons.barcode_reader, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCodeCard extends StatelessWidget {
  const _HistoryCodeCard({required this.product, required this.code});

  final Product product;
  final ProductCode code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: code.type.canShowBarcode
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BarcodeScreen(
                            product: product,
                            code: code,
                            isObsolete: true,
                          ),
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${code.type.label}: ${code.displayValue}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      code.retiredAt == null
                          ? 'Veraltet'
                          : 'Veraltet seit ${_formatDate(code.retiredAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (code.secondaryDisplay case final secondary?)
                      Text(secondary),
                    if (code.note.isNotEmpty) Text(code.note),
                  ],
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Reaktivieren',
              onPressed: () =>
                  AppScope.of(context).reactivateCode(product, code),
              icon: const Icon(Icons.restore),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}, '
      '${two(date.hour)}:${two(date.minute)}';
}
