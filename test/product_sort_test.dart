import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/utils/product_sort.dart';

void main() {
  final now = DateTime(2026, 9, 12);

  Product product({
    required String id,
    required String name,
    String category = 'Obst',
    bool isPromotion = false,
    bool isPinned = false,
    bool isActive = true,
  }) {
    return Product(
      id: id,
      name: name,
      category: category,
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

  test('sortiert Produkte innerhalb eines Bereichs alphabetisch', () {
    final zucchini = product(
      id: '1',
      name: 'Zucchini',
      category: 'Gemüse',
      isPinned: true,
    );
    final apple = product(id: '2', name: 'Apfel', category: 'Obst');
    final banana = product(id: '3', name: 'Banane', category: 'Obst');
    final products = [zucchini, banana, apple]
      ..sort(compareProductsForOverview);

    expect(products, [apple, banana, zucchini]);
  });

  test('berücksichtigt deutsche Umlaute bei der Sortierung', () {
    final banana = product(id: '1', name: 'Banane');
    final apples = product(id: '2', name: 'Äpfel');
    final products = [banana, apples]..sort(compareProductsForOverview);

    expect(products, [apples, banana]);
  });
}
