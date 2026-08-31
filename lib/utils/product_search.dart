import '../models/product.dart';

class RetiredCodeHit {
  const RetiredCodeHit({
    required this.product,
    required this.code,
    this.score = 0,
  });

  final Product product;
  final ProductCode code;
  final int score;
}

class ProductSearchResult {
  const ProductSearchResult({
    required this.currentProducts,
    required this.obsoleteProducts,
    required this.retiredCodes,
  });

  final List<Product> currentProducts;
  final List<Product> obsoleteProducts;
  final List<RetiredCodeHit> retiredCodes;
}

ProductSearchResult searchProducts(List<Product> products, String rawQuery) {
  final query = normalizeSearchText(rawQuery);
  final sortedProducts = [...products]
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  if (query.isEmpty) {
    return ProductSearchResult(
      currentProducts: sortedProducts
          .where((product) => !product.isObsolete)
          .toList(growable: false),
      obsoleteProducts: const [],
      retiredCodes: const [],
    );
  }

  final scoredProducts = <(Product, int)>[];
  final scoredObsoleteProducts = <(Product, int)>[];
  final retired = <RetiredCodeHit>[];

  for (final product in products) {
    final active = product.activeCode;
    final fields = <String>[
      product.name,
      product.category,
      product.description,
      ...product.aliases,
      if (product.isOrganic) 'bio biologisch oeko',
      if (product.isPromotion) 'aktion angebot reduziert rabatt',
      if (active != null) active.value,
      if (active == null) ...product.codes.map((code) => code.value),
    ];
    final score = fields
        .map((field) => _fieldScore(query, normalizeSearchText(field)))
        .fold(0, (best, value) => value > best ? value : best);
    if (score > 0) {
      if (active == null) {
        scoredObsoleteProducts.add((product, score));
      } else {
        scoredProducts.add((product, score));
      }
    }

    for (final code
        in active == null ? const <ProductCode>[] : product.retiredCodes) {
      final codeScore = _fieldScore(query, normalizeSearchText(code.value));
      final nameScore = _fieldScore(query, normalizeSearchText(product.name));
      final best = codeScore > nameScore ? codeScore : nameScore;
      if (best > 0) {
        retired.add(RetiredCodeHit(product: product, code: code, score: best));
      }
    }
  }

  scoredProducts.sort((a, b) {
    final scoreOrder = b.$2.compareTo(a.$2);
    if (scoreOrder != 0) return scoreOrder;
    if (a.$1.isPinned != b.$1.isPinned) return a.$1.isPinned ? -1 : 1;
    return a.$1.name.compareTo(b.$1.name);
  });
  scoredObsoleteProducts.sort((a, b) {
    final scoreOrder = b.$2.compareTo(a.$2);
    if (scoreOrder != 0) return scoreOrder;
    return a.$1.name.compareTo(b.$1.name);
  });
  retired.sort((a, b) {
    final scoreOrder = b.score.compareTo(a.score);
    if (scoreOrder != 0) return scoreOrder;
    return a.product.name.compareTo(b.product.name);
  });

  return ProductSearchResult(
    currentProducts: scoredProducts.map((entry) => entry.$1).toList(),
    obsoleteProducts: scoredObsoleteProducts.map((entry) => entry.$1).toList(),
    retiredCodes: retired,
  );
}

String normalizeSearchText(String input) => input
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(',', '.')
    .replaceAll(RegExp(r'[^a-z0-9.]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _fieldScore(String query, String field) {
  if (field.isEmpty) return 0;
  if (field == query) return 1000;
  if (field.startsWith(query)) return 850 - (field.length - query.length);
  if (field.split(' ').any((word) => word.startsWith(query))) return 750;
  if (field.contains(query)) return 650;

  // Bei Kassencodes wäre eine unscharfe Ziffernfolge gefährlich: 4011 darf
  // nicht als vermeintlicher Treffer für 94011 erscheinen.
  if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(query) ||
      RegExp(r'^\d+(?:\.\d+)?$').hasMatch(field)) {
    return 0;
  }

  final queryWords = query.split(' ');
  final fieldWords = field.split(' ');
  var matchedWords = 0;
  for (final queryWord in queryWords) {
    if (fieldWords.any((word) => _isClose(queryWord, word))) matchedWords++;
  }
  if (matchedWords == queryWords.length) return 500 + matchedWords;
  return 0;
}

bool _isClose(String query, String candidate) {
  if (query.length < 3) return false;
  final maxDistance = query.length >= 5 ? 2 : 1;
  return _damerauLevenshtein(query, candidate, maxDistance) <= maxDistance;
}

int _damerauLevenshtein(String a, String b, int limit) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var previousPrevious = List<int>.filled(b.length + 1, 0);
  var previous = List<int>.generate(b.length + 1, (index) => index);

  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMinimum = current[0];
    for (var j = 1; j <= b.length; j++) {
      final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
          ? 0
          : 1;
      current[j] = _min3(
        current[j - 1] + 1,
        previous[j] + 1,
        previous[j - 1] + substitutionCost,
      );
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        final transposition = previousPrevious[j - 2] + 1;
        if (transposition < current[j]) current[j] = transposition;
      }
      if (current[j] < rowMinimum) rowMinimum = current[j];
    }
    if (rowMinimum > limit) return limit + 1;
    previousPrevious = previous;
    previous = current;
  }
  return previous[b.length];
}

int _min3(int a, int b, int c) {
  var result = a < b ? a : b;
  if (c < result) result = c;
  return result;
}
