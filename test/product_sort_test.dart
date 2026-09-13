import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/utils/product_sort.dart';

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

  test('sortiert aktive Aktionsprodukte vor allen anderen Produkten', () {
    final regularPinned = product(id: '1', name: 'Apfel', isPinned: true);
    final promotion = product(id: '2', name: 'Banane', isPromotion: true);
    final products = [regularPinned, promotion]
      ..sort(compareProductsForOverview);

    expect(products, [promotion, regularPinned]);
  });

  test('behandelt veraltete Aktionsprodukte nicht als Aktion der Woche', () {
    final obsoletePromotion = product(
      id: '1',
      name: 'Apfel',
      isPromotion: true,
      isActive: false,
    );
    final activeRegular = product(id: '2', name: 'Banane');
    final products = [obsoletePromotion, activeRegular]
      ..sort(compareProductsForOverview);

    expect(products, [activeRegular, obsoletePromotion]);
  });
}
