import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/app_controller.dart';
import 'package:rewe_plu_assistent/app_scope.dart';
import 'package:rewe_plu_assistent/data/product_repository.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/screens/search_screen.dart';

void main() {
  testWidgets('gruppiert Aktionen, Pins und weitere Produkte in der Suche', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 9, 15);
    Product product(
      String id,
      String name, {
      bool isPromotion = false,
      bool isPinned = false,
    }) => Product(
      id: id,
      name: name,
      category: 'Obst',
      isPromotion: isPromotion,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'code-$id',
          productId: id,
          type: ProductCodeType.plu,
          value: id,
          isActive: true,
          createdAt: now,
        ),
      ],
    );

    final controller = _SearchController([
      product('regular', 'Normale Birne'),
      product('pinned', 'Angepinnter Apfel', isPinned: true),
      product('promotion', 'Aktionsbanane', isPromotion: true, isPinned: true),
    ]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: const Scaffold(body: SearchScreen(isActive: true)),
        ),
      ),
    );

    expect(find.text('Aktion der Woche'), findsOneWidget);
    expect(find.text('Angepinnte Produkte'), findsOneWidget);
    expect(find.text('Weitere Produkte'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Aktionsbanane')).dy,
      lessThan(tester.getTopLeft(find.text('Angepinnter Apfel')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Angepinnter Apfel')).dy,
      lessThan(tester.getTopLeft(find.text('Normale Birne')).dy),
    );
  });
}

class _SearchController extends AppController {
  _SearchController(this.testProducts) : super(ProductRepository());

  final List<Product> testProducts;

  @override
  List<Product> get products => testProducts;

  @override
  bool get canEdit => false;
}
