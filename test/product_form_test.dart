import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/screens/product_form_screen.dart';

void main() {
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
}
