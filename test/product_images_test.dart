import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';

void main() {
  test('behält mehrere Produktbilder in ihrer Reihenfolge', () {
    final now = DateTime(2026, 8, 31);
    final images = [
      ProductImageData(
        id: 'image-1',
        productId: 'product-1',
        localPath: '/tmp/front.jpg',
        sortOrder: 0,
        createdAt: now,
      ),
      ProductImageData(
        id: 'image-2',
        productId: 'product-1',
        remoteUrl: 'https://example.test/back.jpg',
        sourcePageUrl: 'https://commons.wikimedia.org/wiki/File:back.jpg',
        attribution: 'Erika Muster',
        license: 'CC BY-SA 4.0',
        sortOrder: 1,
        createdAt: now,
      ),
    ];
    final product = Product(
      id: 'product-1',
      name: 'Testprodukt',
      aliases: const ['Alternativname'],
      category: 'Sonstiges',
      createdAt: now,
      updatedAt: now,
      codes: const [],
      images: images,
    );

    expect(product.images, hasLength(2));
    expect(product.primaryImage?.id, 'image-1');
    expect(product.imagePath, '/tmp/front.jpg');
    expect(product.toQueueMap()['images'], hasLength(2));
    expect(product.images.last.license, 'CC BY-SA 4.0');
    expect(
      (product.toQueueMap()['product'] as Map<String, Object?>)['aliases'],
      ['Alternativname'],
    );
  });
}
