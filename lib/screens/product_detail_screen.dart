import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/app_constants.dart';
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Container(
              decoration: BoxDecoration(
                color: reweDarkRed,
                borderRadius: BorderRadius.circular(12.0),
              ),
            margin: const EdgeInsets.only(right: 8.0),
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Bearbeiten',
                  color: Colors.white,
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
                  iconColor: Colors.white,
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
          )
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black38,
                        ),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1.0),
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Chip(
                          avatar: Icon(Icons.category_outlined, size: 18, color: Colors.grey[700]!),
                          backgroundColor: Colors.grey[200],
                          side: BorderSide(color: Colors.grey[400]!),
                          label: Text(product.category, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey[700])),
                        ),
                        if (product.isOrganic)
                          Chip(
                            avatar: Icon(Icons.eco, size: 17, color: Colors.green[900],),
                            label: Text(
                              'BIO',
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.green[900]),
                            ),
                            backgroundColor: Colors.green[100],
                            side: BorderSide(color: Colors.green[400]!),
                          ),
                        if (product.isPromotion)
                          Chip(
                            avatar: Icon(Icons.local_offer, size: 17, color: reweDarkRed,),
                            label: Text(
                              'AKTION',
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: reweDarkRed),
                            ),
                            backgroundColor: reweRedContainer,
                            side: BorderSide(color: reweRed),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (product.images.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: product.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => _openGallery(context, product, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 71,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.black38,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1.0),
                          child: _ProductImageThumbnail(
                            image: product.images[index],
                          ),
                        ),
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
          if (product.aliases.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Auch bekannt als',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                for (final alias in product.aliases)
                  Chip(
                    avatar: const Icon(Icons.alternate_email, size: 16, color: reweDarkTeal,),
                    backgroundColor: reweTealContainer,
                    side: BorderSide.none,
                    label: Text(alias),
                  ),
              ],
            ),
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
              color: reweDarkRed,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dieses Produkt ist vollständig veraltet. Unten kann '
                        'ein Code reaktiviert werden.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
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
            Card(
              color: reweTealContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                      color: reweTeal
                  )
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Noch keine veralteten Codes.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: reweDarkTeal),),
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
      color: reweDarkRed,
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
                    Text(code.type.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,)),
                    const SizedBox(height: 3),
                    Text(
                      code.displayValue,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    if (code.secondaryDisplay case final secondary?)
                      Text(
                        secondary,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    if (code.note.isNotEmpty) Text(code.note, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white,)),
                  ],
                ),
              ),
              if (code.type.canShowBarcode)
                const Icon(Icons.barcode_reader, size: 34, color: Colors.white,),
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
      color: reweTealContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: reweTeal
        )
      ),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${code.type.label}: ${code.displayValue}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        decoration: TextDecoration.lineThrough,
                        decorationThickness: 2,
                        color: reweDarkTeal,
                        decorationColor: reweDarkTeal,
                        fontWeight: FontWeight.w700,
                      )
                    ),
                    Text(
                      code.retiredAt == null
                          ? 'Veraltet'
                          : 'Veraltet seit ${_formatDate(code.retiredAt!)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: reweDarkTeal),
                    ),
                    if (code.secondaryDisplay case final secondary?)
                      Text(secondary, style: Theme.of(context).textTheme.bodySmall),
                    if (code.note.isNotEmpty) Text(code.note, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Reaktivieren',
                style: IconButton.styleFrom(
                    backgroundColor: reweTeal,
                    foregroundColor: reweDarkTeal,
                ),
                onPressed: () =>
                    AppScope.of(context).reactivateCode(product, code),
                icon: const Icon(Icons.restore),
              ),
            ],
          ),
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
