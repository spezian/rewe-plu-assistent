import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/screens/product_form_screen.dart';

void main() {
  testWidgets('bietet REWE-Bildsuche auch ohne Unsplash-Schlüssel an', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 16);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductFormScreen(
          product: Product(
            id: 'image-search-product',
            name: 'Pfirsich',
            category: 'Obst',
            createdAt: now,
            updatedAt: now,
            codes: const [],
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Bild hinzufügen'));
    await tester.tap(find.text('Bild hinzufügen'));
    await tester.pumpAndSettle();
    final option = find.ancestor(
      of: find.text('Bilder im Internet vorschlagen'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(option).enabled, isTrue);
    expect(find.text('REWE und Unsplash: „Pfirsich“'), findsOneWidget);
  });

  testWidgets('lässt auch einen bereits gespeicherten Code entfernen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 9, 13);
    final product = Product(
      id: 'product-1',
      name: 'Apfel',
      category: 'Obst',
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'code-1',
          productId: 'product-1',
          type: ProductCodeType.plu,
          value: '4011',
          isActive: true,
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ProductFormScreen(product: product)),
    );

    final removeButton = find.byTooltip('Code entfernen');
    expect(removeButton, findsOneWidget);
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pump();

    expect(
      find.text(
        'Dieses Produkt hat keinen Code und wird als veraltet angezeigt.',
      ),
      findsOneWidget,
    );
    expect(find.text('4011'), findsNothing);
  });

  testWidgets('zeigt und ändert den Pin-Status in der Produktbearbeitung', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 9, 15);
    final product = Product(
      id: 'product-pin',
      name: 'Apfel',
      category: 'Obst',
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'code-pin',
          productId: 'product-pin',
          type: ProductCodeType.plu,
          value: '4011',
          isActive: true,
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ProductFormScreen(product: product)),
    );

    final tile = find.byKey(const ValueKey('product-pinned-switch'));
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });

  testWidgets('bietet Info als Texteingabe ohne Kassen-Kategorie an', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProductFormScreen()));

    final typeDropdown = find.byType(DropdownButtonFormField<ProductCodeType>);
    await tester.ensureVisible(typeDropdown);
    await tester.tap(typeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info').last);
    await tester.pumpAndSettle();

    expect(find.text('Info *'), findsOneWidget);
    expect(find.text('z. B. Nur stückweise verkaufen'), findsOneWidget);
    expect(find.text('Kategorie im Bedienerdisplay *'), findsNothing);
  });
}
