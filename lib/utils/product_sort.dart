import '../models/product.dart';

/// Sort order used by product overview lists.
///
/// Current promotional products always lead the list. Obsolete products never
/// count as a weekly promotion, even if their promotion flag is still set.
/// Products within those visible sections are sorted alphabetically by name.
int compareProductsForOverview(Product a, Product b) {
  if (a.isObsolete != b.isObsolete) return a.isObsolete ? 1 : -1;

  if (!a.isObsolete && a.isPromotion != b.isPromotion) {
    return a.isPromotion ? -1 : 1;
  }

  return compareProductNamesAlphabetically(a, b);
}

int compareProductNamesAlphabetically(Product a, Product b) {
  final normalizedOrder = _alphabeticalKey(a.name)
      .compareTo(_alphabeticalKey(b.name));
  if (normalizedOrder != 0) return normalizedOrder;

  final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (nameOrder != 0) return nameOrder;
  return a.id.compareTo(b.id);
}

String _alphabeticalKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss');
