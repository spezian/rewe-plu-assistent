import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rewe_plu_assistent/models/product.dart';
import 'package:rewe_plu_assistent/screens/product_gallery_screen.dart';

void main() {
  testWidgets(
    'shows REWE attribution once and keeps Unsplash attribution on older images',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductGalleryScreen(
            title: 'Pfirsich',
            images: [
              ProductImageData(
                id: 'rewe',
                productId: 'product',
                sourcePageUrl:
                    'https://www.rewe.de/suche/uebersicht?searchTerm=Pfirsich',
                attribution: 'REWE',
                sortOrder: 0,
                createdAt: DateTime(2026),
              ),
              ProductImageData(
                id: 'unsplash',
                productId: 'product',
                sourcePageUrl: 'https://unsplash.com/photos/example',
                attribution: 'Photographer',
                sortOrder: 1,
                createdAt: DateTime(2026),
              ),
            ],
          ),
        ),
      );
      expect(find.text('REWE'), findsOneWidget);
      expect(find.textContaining('Unsplash'), findsNothing);
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('Photographer · Unsplash'), findsOneWidget);
    },
  );
}
