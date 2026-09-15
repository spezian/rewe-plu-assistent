import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/app_controller.dart';
import 'package:rewe_plu_assistent/app_scope.dart';
import 'package:rewe_plu_assistent/core/app_constants.dart';
import 'package:rewe_plu_assistent/data/product_repository.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/screens/home_screen.dart';

void main() {
  final now = DateTime(2026, 9, 12);

  Product product({
    required String id,
    required String name,
    bool isPromotion = false,
    bool isPinned = false,
    bool isActive = true,
  }) {
    return Product(
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
          isActive: isActive,
          createdAt: now,
        ),
      ],
    );
  }

  testWidgets('zeigt nur aktive Aktionsprodukte als Aktion der Woche', (
    tester,
  ) async {
    final promotion = product(
      id: '1',
      name: 'Aktionsbanane',
      isPromotion: true,
    );
    final regular = product(id: '2', name: 'Normaler Apfel');
    final obsoletePromotion = product(
      id: '3',
      name: 'Veraltete Birne',
      isPromotion: true,
      isActive: false,
    );
    final controller = _ProductListController([
      regular,
      obsoletePromotion,
      promotion,
    ]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: const Scaffold(body: ProductListPage()),
        ),
      ),
    );

    expect(find.text('Aktion der Woche'), findsOneWidget);
    expect(find.text('Weitere Produkte'), findsOneWidget);
    expect(find.text('Veraltete Birne'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Aktionsbanane')).dy,
      lessThan(tester.getTopLeft(find.text('Normaler Apfel')).dy),
    );

    await tester.dragUntilVisible(
      find.text(obsoleteCategory),
      find.byType(ListView).first,
      const Offset(-300, 0),
    );
    await tester.tap(find.text(obsoleteCategory));
    await tester.pump();

    expect(find.text('Aktion der Woche'), findsNothing);
    expect(find.text('Veraltete Birne'), findsOneWidget);
  });

  testWidgets('ordnet angepinnte Produkte unter Aktionen ein', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final promotion = product(
      id: 'promotion',
      name: 'Aktionsbanane',
      isPromotion: true,
      isPinned: true,
    );
    final pinned = product(
      id: 'pinned',
      name: 'Angepinnter Apfel',
      isPinned: true,
    );
    final regular = product(id: 'regular', name: 'Normale Birne');
    final controller = _ProductListController([regular, pinned, promotion]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: const Scaffold(body: ProductListPage()),
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
    expect(find.text('Aktionsbanane'), findsOneWidget);
  });
}

class _ProductListController extends AppController {
  _ProductListController(this.testProducts) : super(ProductRepository());

  final List<Product> testProducts;

  @override
  List<Product> get products => testProducts;

  @override
  bool get canEdit => false;
}
