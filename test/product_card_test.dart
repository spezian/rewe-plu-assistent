import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/widgets/product_card.dart';
import 'package:rewe_plu_assistent/widgets/product_image.dart';

void main() {
  test('verwendet für Kassenkacheln eine kurze Listenbezeichnung', () {
    expect(ProductCodeType.cashierTile.label, 'Kassenkachel');
    expect(ProductCodeType.cashierTile.productListLabel, 'Kachel');
  });

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
    final cardBottom = tester.getBottomRight(find.byType(ProductCard)).dy;
    final codeButtonBottom = tester
        .getBottomRight(find.byKey(const ValueKey('product-code-button')))
        .dy;
    expect(codeButtonBottom, closeTo(cardBottom - 9, 0.01));

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

  testWidgets('zeigt Kachel und Kategorie ohne Barcode-Aktion', (tester) async {
    final now = DateTime(2026, 8, 31);
    final product = Product(
      id: 'p2',
      name: 'Pitahaya',
      category: 'Obst',
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'tile-1',
          productId: 'p2',
          type: ProductCodeType.cashierTile,
          value: 'Kachel 6',
          displayCategory: 'Obst > Exoten',
          isActive: true,
          createdAt: now,
        ),
      ],
    );
    var barcodeOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(
            product: product,
            onTogglePinned: () async {},
            onOpenDetails: () {},
            onOpenImages: () {},
            onShowCode: () => barcodeOpened = true,
          ),
        ),
      ),
    );

    expect(find.text('Kachel: Kachel 6'), findsOneWidget);
    expect(find.text('unter Obst > Exoten'), findsOneWidget);
    await tester.tap(find.text('Pitahaya'));
    expect(barcodeOpened, isFalse);
  });

  testWidgets('zeigt einen Infotext ohne vorangestelltes Info-Label', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 15);
    final product = Product(
      id: 'info-product',
      name: 'Lose Ware',
      category: 'Sonstiges',
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'info-1',
          productId: 'info-product',
          type: ProductCodeType.info,
          value: 'Nur stückweise verkaufen',
          isActive: true,
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(
            product: product,
            onOpenDetails: () {},
            onOpenImages: () {},
            onShowCode: () {},
          ),
        ),
      ),
    );

    expect(find.text('Nur stückweise verkaufen'), findsOneWidget);
    expect(find.text('Info: Nur stückweise verkaufen'), findsNothing);
  });

  testWidgets('deaktiviert die Wischänderung im Lesemodus', (tester) async {
    final now = DateTime(2026, 8, 31);
    final product = Product(
      id: 'read-only',
      name: 'Banane',
      category: 'Obst',
      createdAt: now,
      updatedAt: now,
      codes: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(
            product: product,
            onOpenDetails: () {},
            onOpenImages: () {},
            onShowCode: () {},
          ),
        ),
      ),
    );

    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(dismissible.direction, DismissDirection.none);
  });

  testWidgets('wächst mit mehrzeiligem Titel, Kategorie und Kachelcode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 9, 15);
    const name =
        'Börek Stange Hackfleisch mit besonders ausführlicher Bezeichnung';
    const category = 'Backwaren und herzhafte Snacks aus der Bedienung';
    const value =
        'Börek Stange Hackfleisch unter Lauge und weiteren herzhaften Snacks';
    const displayCategory =
        'Lauge, Snacks und weitere Artikel aus der warmen Theke';
    final product = Product(
      id: 'multiline-product',
      name: name,
      category: category,
      aliases: const ['Hackfleischrolle', 'gefüllte Teigstange'],
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'multiline-code',
          productId: 'multiline-product',
          type: ProductCodeType.cashierTile,
          value: value,
          displayCategory: displayCategory,
          isActive: true,
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ProductCard(
                product: product,
                onOpenDetails: () {},
                onOpenImages: () {},
                onShowCode: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text(name)).maxLines, isNull);
    expect(tester.widget<Text>(find.textContaining(category)).maxLines, isNull);
    expect(tester.widget<Text>(find.text('Kachel: $value')).maxLines, isNull);
    expect(
      tester.widget<Text>(find.text('unter $displayCategory')).maxLines,
      isNull,
    );

    final cardSize = tester.getSize(find.byType(ProductCard));
    final imageSize = tester.getSize(find.byType(ProductImage));
    expect(cardSize.height, greaterThan(120));
    expect(imageSize.height, closeTo(cardSize.height - 2, 0.01));
  });
}
