import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rewe_plu_assistent/data/image_suggestion_service.dart';

void main() {
  final fixture = File('test/fixtures/rewe_search.html').readAsStringSync();

  test(
    'extracts REWE product images and names, excludes recipes and placeholders',
    () {
      final results = parseReweImageSuggestions(fixture);
      expect(results, hasLength(1));
      final image = results.single;
      expect(image.title, 'Pfirsich aus der Region');
      expect(Uri.parse(image.imageUrl).queryParameters, {
        'impolicy': 's-offers',
        'imwidth': '800',
      });
      expect(Uri.parse(image.thumbnailUrl!).queryParameters['imwidth'], '400');
      expect(
        Uri.parse(image.sourcePageUrl).queryParameters['searchTerm'],
        image.title,
      );
      expect(image.attribution, 'REWE');
      expect(image.license, isNull);
    },
  );

  test('deduplicates product images and decodes names', () {
    final modified = fixture.replaceAll(
      'Pfirsich aus der Region',
      'Äpfel &amp; Birnen',
    );
    final results = parseReweImageSuggestions('$modified$modified');
    expect(results, hasLength(1));
    expect(results.single.title, 'Äpfel & Birnen');
  });

  test('rejects unrelated HTML and untrusted image hosts instead of returning no matches', () {
    expect(
      () => parseReweImageSuggestions('<html>Bot protection</html>'),
      throwsA(isA<ImageSearchException>()),
    );
    expect(
      () => parseReweImageSuggestions(
        fixture.replaceAll(
          'img.rewe-static.de',
          'img.rewe-static.de.evil.test',
        ),
      ),
      throwsA(isA<ImageSearchException>()),
    );
    expect(
      parseReweImageSuggestions(
        '<div class="spr-search"><div id="spr-search-content-grid-products"></div></div>',
      ),
      isEmpty,
    );
  });

  test(
    'native REWE search does not need an Unsplash key and encodes the query',
    () async {
      final service = ImageSuggestionService(
        reweProxyUrl: '',
        unsplashKey: '',
        client: MockClient((request) async {
          expect(request.url.host, 'www.rewe.de');
          expect(request.url.queryParameters['searchTerm'], 'Äpfel & Birnen');
          expect(request.headers['Authorization'], isNull);
          return http.Response(
            fixture,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      expect(await service.search(' Äpfel & Birnen '), hasLength(1));
    },
  );

  test(
    'web search, preview and import use our proxy while attribution stays REWE',
    () async {
      final service = ImageSuggestionService(
        isWeb: true,
        reweProxyUrl: 'https://project.test/functions/v1/rewe-images',
        client: MockClient((request) async {
          expect(request.url.queryParameters['query'], 'Pfirsich');
          expect(request.headers['user-agent'], isNull);
          return http.Response(fixture, 200);
        }),
      );
      final result = (await service.search('Pfirsich')).single;
      for (final url in [result.imageUrl, result.thumbnailUrl!]) {
        expect(Uri.parse(url).host, 'project.test');
        expect(
          Uri.parse(Uri.parse(url).queryParameters['image']!).host,
          'img.rewe-static.de',
        );
      }
      expect(Uri.parse(result.sourcePageUrl).host, 'www.rewe.de');
    },
  );

  test('missing configuration and blank queries never send requests', () async {
    final service = ImageSuggestionService(
      isWeb: true,
      reweProxyUrl: '',
      unsplashKey: '',
      client: MockClient((_) async => fail('Unexpected network call')),
    );
    expect(await service.search(' '), isEmpty);
    await expectLater(
      service.search('Pfirsich'),
      throwsA(isA<ImageSearchException>()),
    );
    await expectLater(
      service.search('Pfirsich', source: ImageSearchSource.unsplash),
      throwsA(isA<ImageSearchException>()),
    );
  });

  test('reports blocked, unavailable and timed out requests', () async {
    for (final status in [403, 429, 404, 502]) {
      final service = ImageSuggestionService(
        reweProxyUrl: 'https://project.test/functions/v1/rewe-images',
        client: MockClient((_) async => http.Response('error', status)),
      );
      await expectLater(
        service.search('Pfirsich'),
        throwsA(isA<ImageSearchException>()),
      );
    }
    final service = ImageSuggestionService(
      reweProxyUrl: '',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      service.search('Pfirsich'),
      throwsA(isA<ImageSearchException>()),
    );
  });

  test('Unsplash still uses its API and retains attribution', () async {
    final service = ImageSuggestionService(
      unsplashKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.host, 'api.unsplash.com');
        expect(request.headers['Authorization'], 'Client-ID test-key');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'urls': {'small': 'https://images.unsplash.com/example'},
                'links': {'html': 'https://unsplash.com/photos/example'},
                'user': {'name': 'Photographer'},
              },
              {'urls': null},
            ],
          }),
          200,
        );
      }),
    );
    final results = await service.search(
      'peach',
      source: ImageSearchSource.unsplash,
    );
    expect(results, hasLength(1));
    expect(results.single.attribution, 'Photographer');
  });
}
