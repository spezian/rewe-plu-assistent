import '../models/product.dart';

/// Sort order used by product overview lists.
///
/// Current promotional products always lead the list. Obsolete products never
/// count as a weekly promotion, even if their promotion flag is still set.
int compareProductsForOverview(Product a, Product b) {
  if (a.isObsolete != b.isObsolete) return a.isObsolete ? 1 : -1;

  if (!a.isObsolete && a.isPromotion != b.isPromotion) {
    return a.isPromotion ? -1 : 1;
  }

  if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

  final categoryOrder = a.category.compareTo(b.category);
  if (categoryOrder != 0) return categoryOrder;

  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
