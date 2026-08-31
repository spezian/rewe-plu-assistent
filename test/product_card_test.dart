import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/widgets/product_card.dart';

void main() {
  testWidgets('zeigt den aktuellen PLU direkt und öffnet ihn per Touch', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 31);
    final product = Product(
      id: 'p1',
      name: 'Banane',
      category: 'Obst',
      isOrganic: true,
      isPromotion: true,
      createdAt: now,
      updatedAt: now,
      images: [
        ProductImageData(
          id: 'i1',
          productId: 'p1',
          localPath: '/nicht-vorhanden.jpg',
          sortOrder: 0,
          createdAt: now,
        ),
      ],
      codes: [
        ProductCode(
          id: 'c1',
          productId: 'p1',
          type: ProductCodeType.plu,
          value: '4011',
          isActive: true,
          createdAt: now,
        ),
      ],
    );
    var barcodeOpened = false;
    var imageOpened = false;
    var detailsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(
            product: product,
            onTogglePinned: () async {},
            onOpenDetails: () => detailsOpened = true,
            onOpenImages: () => imageOpened = true,
            onShowCode: () => barcodeOpened = true,
          ),
        ),
      ),
    );

    expect(find.text('PLU: 4011'), findsOneWidget);
    expect(find.text('BIO'), findsOneWidget);
    expect(find.text('AKTION'), findsOneWidget);
    await tester.tap(find.text('PLU: 4011'));
    expect(barcodeOpened, isTrue);

    barcodeOpened = false;
    await tester.tap(find.text('Banane'));
    expect(barcodeOpened, isTrue);

    await tester.tap(find.byTooltip('Bilder im Vollbild'));
    expect(imageOpened, isTrue);

    await tester.tap(find.byTooltip('Produktdetails'));
    expect(detailsOpened, isTrue);
  });
}
