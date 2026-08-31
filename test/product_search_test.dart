import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/utils/product_search.dart';

void main() {
  final now = DateTime(2026, 8, 31, 10);
  final product = Product(
    id: 'product-1',
    name: 'Bio Banane',
    category: 'Obst',
    createdAt: now,
    updatedAt: now,
    codes: [
      ProductCode(
        id: 'current',
        productId: 'product-1',
        type: ProductCodeType.plu,
        value: '4011',
        isActive: true,
        createdAt: now,
      ),
      ProductCode(
        id: 'old',
        productId: 'product-1',
        type: ProductCodeType.plu,
        value: '94011',
        isActive: false,
        createdAt: now.subtract(const Duration(days: 30)),
        retiredAt: now,
      ),
    ],
  );

  test('findet Produkte trotz kleinem Tippfehler', () {
    final result = searchProducts([product], 'banna');
    expect(result.currentProducts, [product]);
  });

  test('trennt veraltete Codes von aktuellen Treffern', () {
    final result = searchProducts([product], '94011');
    expect(result.currentProducts, isEmpty);
    expect(result.retiredCodes.single.code.id, 'old');
  });

  test('normalisiert Umlaute und Satzzeichen', () {
    expect(normalizeSearchText('Süß & Groß'), 'suess gross');
  });

  test('findet ein Produkt über einen alternativen Namen', () {
    final pitahaya = Product(
      id: 'product-2',
      name: 'Pitahaya',
      aliases: const ['Drachenfrucht', 'Dragon Fruit'],
      category: 'Obst',
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'dragon-current',
          productId: 'product-2',
          type: ProductCodeType.plu,
          value: '3108',
          isActive: true,
          createdAt: now,
        ),
      ],
    );

    final result = searchProducts([pitahaya], 'Drachenfrucht');
    expect(result.currentProducts.single.name, 'Pitahaya');
  });

  test('führt ein Produkt ohne aktiven Code als veraltet', () {
    final obsolete = product.copyWith(
      codes: product.codes
          .map((code) => code.copyWith(isActive: false, retiredAt: now))
          .toList(),
    );

    final result = searchProducts([obsolete], 'Bio Banane');
    expect(result.currentProducts, isEmpty);
    expect(result.obsoleteProducts.single.id, product.id);
    expect(obsolete.isObsolete, isTrue);
  });

  test('findet Produkte über Bio- und Aktionskennzeichnung', () {
    final marked = product.copyWith(isOrganic: true, isPromotion: true);

    expect(searchProducts([marked], 'bio').currentProducts, [marked]);
    expect(searchProducts([marked], 'aktion').currentProducts, [marked]);
  });

  test('findet eine Bedienerkachel über Kachel und Display-Kategorie', () {
    final tileProduct = Product(
      id: 'product-3',
      name: 'Pitahaya',
      category: 'Obst',
      createdAt: now,
      updatedAt: now,
      codes: [
        ProductCode(
          id: 'tile-current',
          productId: 'product-3',
          type: ProductCodeType.cashierTile,
          value: 'Kachel 6',
          displayCategory: 'Obst > Exoten',
          isActive: true,
          createdAt: now,
        ),
      ],
    );

    expect(searchProducts([tileProduct], 'Kachel 6').currentProducts, [
      tileProduct,
    ]);
    expect(searchProducts([tileProduct], 'Exoten').currentProducts, [
      tileProduct,
    ]);
  });
}
