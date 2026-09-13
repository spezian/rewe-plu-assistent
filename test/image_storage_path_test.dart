import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/data/sync_service.dart';

void main() {
  test('behält für ein vorhandenes Cloud-Original den bisherigen Pfad', () {
    final path = storagePathForProductImage(
      currentUrl:
          'https://project.supabase.co/storage/v1/object/public/'
          'product-images/market-1/product-1/image-1.png',
      marketId: 'market-1',
      productId: 'product-1',
      fileStem: 'image-1',
      fallbackExtension: '.jpg',
    );

    expect(path, 'market-1/product-1/image-1.png');
  });

  test('verwendet für fremde URLs den sicheren Produktpfad', () {
    final path = storagePathForProductImage(
      currentUrl: 'https://example.test/legacy/image-1.png',
      marketId: 'market-1',
      productId: 'product-1',
      fileStem: 'image-1',
      fallbackExtension: '.jpg',
    );

    expect(path, 'market-1/product-1/image-1.jpg');
  });
}
