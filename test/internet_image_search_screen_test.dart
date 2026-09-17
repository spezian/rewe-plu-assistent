import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rewe_plu_assistent/data/image_suggestion_service.dart';
import 'package:rewe_plu_assistent/screens/internet_image_search_screen.dart';

class _SearchService extends ImageSuggestionService {
  final requests =
      <(String, ImageSearchSource, Completer<List<RemoteImageSuggestion>>)>[];
  String? unsplashUnavailable;

  @override
  String? unavailableReason(ImageSearchSource source) =>
      source == ImageSearchSource.unsplash ? unsplashUnavailable : null;

  @override
  Future<List<RemoteImageSuggestion>> search(
    String query, {
    ImageSearchSource source = ImageSearchSource.rewe,
  }) {
    final result = Completer<List<RemoteImageSuggestion>>();
    requests.add((query, source, result));
    return result.future;
  }
}

const _image = RemoteImageSuggestion(
  imageUrl: 'https://example.test/peach.png',
  sourcePageUrl:
      'https://www.rewe.de/suche/uebersicht?searchTerm=Pfirsich#produkte',
  title: 'Pfirsich aus der Region',
  attribution: 'REWE',
);

void main() {
  testWidgets(
    'starts with REWE and switches sources without accepting stale responses',
    (tester) async {
      final service = _SearchService();
      await tester.pumpWidget(
        MaterialApp(
          home: InternetImageSearchScreen(
            initialQuery: 'Pfirsich',
            service: service,
          ),
        ),
      );
      expect(service.requests.single.$2, ImageSearchSource.rewe);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Unsplash'));
      await tester.pump();
      expect(service.requests.last.$2, ImageSearchSource.unsplash);
      service.requests.first.$3.completeError(
        const ImageSearchException('Old error'),
      );
      service.requests.last.$3.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Old error'), findsNothing);
      expect(find.textContaining('Keine passenden Bilder'), findsOneWidget);
    },
  );

  testWidgets(
    'new search immediately clears errors, supports retry and disposal during a request',
    (tester) async {
      final service = _SearchService();
      await tester.pumpWidget(
        MaterialApp(
          home: InternetImageSearchScreen(
            initialQuery: 'Pfirsich',
            service: service,
          ),
        ),
      );
      service.requests.single.$3.completeError(
        const ImageSearchException('REWE blockiert'),
      );
      await tester.pumpAndSettle();
      expect(find.text('REWE blockiert'), findsOneWidget);
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pump();
      expect(find.text('REWE blockiert'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      service.requests.last.$3.complete([]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unconfigured Unsplash leaves REWE available and preserves the query',
    (tester) async {
      final service = _SearchService()
        ..unsplashUnavailable = 'Unsplash nicht eingerichtet';
      await tester.pumpWidget(
        MaterialApp(
          home: InternetImageSearchScreen(initialQuery: '', service: service),
        ),
      );
      expect(service.requests, isEmpty);
      expect(find.textContaining('Gib einen Produktnamen'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Birne');
      await tester.tap(find.text('Unsplash'));
      await tester.pumpAndSettle();
      expect(find.text('Unsplash nicht eingerichtet'), findsOneWidget);
      expect(service.requests, isEmpty);
      await tester.tap(find.text('REWE'));
      await tester.pump();
      expect(service.requests.single.$1, 'Birne');
      service.requests.single.$3.complete([]);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('returns the selected image including source metadata', (
    tester,
  ) async {
    final service = _SearchService();
    RemoteImageSuggestion? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.of(context)
                    .push<RemoteImageSuggestion>(
                      MaterialPageRoute(
                        builder: (_) => InternetImageSearchScreen(
                          initialQuery: 'Pfirsich',
                          service: service,
                        ),
                      ),
                    );
              },
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    service.requests.single.$3.complete([_image]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pfirsich aus der Region'));
    await tester.pumpAndSettle();
    expect(selected, same(_image));
    expect(tester.takeException(), isNull);
  });
}
