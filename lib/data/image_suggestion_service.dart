import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../core/app_constants.dart';

enum ImageSearchSource {
  rewe('REWE'),
  unsplash('Unsplash');

  const ImageSearchSource(this.label);
  final String label;
}

class RemoteImageSuggestion {
  const RemoteImageSuggestion({
    required this.imageUrl,
    required this.sourcePageUrl,
    this.thumbnailUrl,
    this.title,
    this.attribution,
    this.license,
  });

  final String imageUrl;
  final String sourcePageUrl;
  final String? thumbnailUrl;
  final String? title;
  final String? attribution;
  final String? license;
}

class ImageSearchException implements Exception {
  const ImageSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

Uri reweSearchPage(String query) => Uri.https(
  'www.rewe.de',
  '/suche/uebersicht',
  {'searchTerm': query},
).replace(fragment: 'produkte');

class ImageSuggestionService {
  const ImageSuggestionService({
    this.client,
    this.unsplashKey = unsplashAccessKey,
    this.reweProxyUrl,
    this.isWeb = kIsWeb,
    this.timeout = const Duration(seconds: 20),
  });

  final http.Client? client;
  final String unsplashKey;
  final String? reweProxyUrl;
  final bool isWeb;
  final Duration timeout;

  Uri? get _proxy {
    final url =
        reweProxyUrl ??
        (hasSupabaseConfiguration
            ? '$supabaseUrl/functions/v1/rewe-images'
            : '');
    return url.isEmpty ? null : Uri.parse(url);
  }

  String? unavailableReason(ImageSearchSource source) {
    if (source == ImageSearchSource.unsplash && unsplashKey.trim().isEmpty) {
      return 'Die Unsplash-Suche ist nicht eingerichtet. '
          'Du kannst stattdessen im REWE-Tab suchen.';
    }
    if (source == ImageSearchSource.rewe && isWeb && _proxy == null) {
      return 'Die REWE-Bildsuche ist für diese Web-App noch nicht eingerichtet.';
    }
    return null;
  }

  Future<List<RemoteImageSuggestion>> search(
    String query, {
    ImageSearchSource source = ImageSearchSource.rewe,
  }) async {
    query = query.trim();
    if (query.isEmpty) return [];
    if (query.length > 120) {
      throw const ImageSearchException(
        'Bitte einen kürzeren Suchbegriff eingeben.',
      );
    }
    final unavailable = unavailableReason(source);
    if (unavailable != null) throw ImageSearchException(unavailable);
    try {
      return source == ImageSearchSource.rewe
          ? await _searchRewe(query)
          : await _searchUnsplash(query);
    } on TimeoutException {
      throw const ImageSearchException(
        'Die Bildsuche dauert zu lange. Bitte erneut versuchen.',
      );
    } on http.ClientException {
      throw const ImageSearchException(
        'Die Bildsuche ist nicht erreichbar. Bitte die Internetverbindung prüfen.',
      );
    } on FormatException {
      throw const ImageSearchException(
        'Die Antwort der Bildsuche konnte nicht gelesen werden.',
      );
    }
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) =>
      (client?.get(uri, headers: headers) ?? http.get(uri, headers: headers))
          .timeout(timeout);

  Future<List<RemoteImageSuggestion>> _searchRewe(String query) async {
    final proxy = _proxy;
    final uri =
        proxy?.replace(queryParameters: {'query': query}) ??
        reweSearchPage(query).removeFragment();
    final response = await _get(
      uri,
      headers: {'Accept': 'text/html', if (!isWeb) 'User-Agent': userAgent},
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const ImageSearchException(
          'REWE blockiert den automatischen Abruf vorübergehend. '
          'Versuche es später erneut oder öffne die REWE-Suche.',
        );
      }
      if (proxy != null && {401, 404}.contains(response.statusCode)) {
        throw const ImageSearchException(
          'Die REWE-Bildsuche ist auf dem Server noch nicht eingerichtet.',
        );
      }
      throw const ImageSearchException(
        'REWE-Bilder konnten nicht geladen werden. Bitte später erneut versuchen.',
      );
    }
    final results = parseReweImageSuggestions(utf8.decode(response.bodyBytes));
    if (!isWeb || proxy == null) return results;
    // Both Flutter's image renderer and the later download need CORS. Keep the
    // original REWE page as attribution, but load image bytes through our proxy.
    return results
        .map(
          (image) => RemoteImageSuggestion(
            imageUrl: proxy
                .replace(queryParameters: {'image': image.imageUrl})
                .toString(),
            thumbnailUrl: proxy
                .replace(
                  queryParameters: {
                    'image': image.thumbnailUrl ?? image.imageUrl,
                  },
                )
                .toString(),
            sourcePageUrl: image.sourcePageUrl,
            title: image.title,
            attribution: image.attribution,
          ),
        )
        .toList(growable: false);
  }

  Future<List<RemoteImageSuggestion>> _searchUnsplash(String query) async {
    final response = await _get(
      Uri.https('api.unsplash.com', '/search/photos', {
        'page': '1',
        'per_page': '20',
        'query': query,
      }),
      headers: {
        'Authorization': 'Client-ID $unsplashKey',
        'Accept-Version': 'v1',
        if (!isWeb) 'User-Agent': userAgent,
      },
    );
    if (response.statusCode != 200) {
      throw const ImageSearchException(
        'Unsplash-Bilder konnten nicht geladen werden. Bitte später erneut versuchen.',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['results'] is! List) {
      throw const FormatException('Missing Unsplash results');
    }
    final suggestions = <RemoteImageSuggestion>[];
    for (final photo in data['results']) {
      if (photo is! Map) continue;
      final urls = photo['urls'];
      final links = photo['links'];
      final user = photo['user'];
      if (urls is! Map || links is! Map) continue;
      final image = urls['small'];
      final page = links['html'];
      if (image is! String || page is! String) continue;
      suggestions.add(
        RemoteImageSuggestion(
          imageUrl: image,
          sourcePageUrl: page,
          attribution: user is Map ? user['name'] as String? : null,
        ),
      );
    }
    return suggestions;
  }
}

/// Extract only product tiles, excluding recipes, navigation and placeholders.
/// REWE uses data-src for lazy images and buttons instead of product links.
List<RemoteImageSuggestion> parseReweImageSuggestions(String source) {
  final document = html.parse(source);
  final tiles = document.querySelectorAll('article[data-product-tile]');
  if (tiles.isEmpty &&
      document.querySelector(
            '.spr-search, #spr-search-content-grid-products',
          ) ==
          null) {
    throw const ImageSearchException(
      'Die REWE-Produktliste konnte nicht gelesen werden. '
      'Die Seite wurde möglicherweise geändert oder der Abruf blockiert.',
    );
  }
  final results = <RemoteImageSuggestion>[];
  final seen = <String>{};
  for (final tile in tiles) {
    final image = tile.querySelector('.spr-product-image img');
    if (image == null) continue;
    final raw = image.attributes['data-src'] ?? image.attributes['src'];
    if (raw == null) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'img.rewe-static.de' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        !RegExp(r'^/\d+/[\w-]+\.(png|jpe?g|webp)$').hasMatch(uri.path)) {
      continue;
    }
    final title =
        (tile.querySelector('.spr-product-information__title')?.text ??
                image.attributes['alt'] ??
                '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (title.isEmpty) continue;
    if (!seen.add(uri.path)) continue;
    final link = tile.querySelector('a[href]')?.attributes['href'];
    final page = link == null ? null : Uri.https('www.rewe.de').resolve(link);
    results.add(
      RemoteImageSuggestion(
        imageUrl: uri
            .replace(
              queryParameters: {...uri.queryParameters, 'imwidth': '800'},
            )
            .toString(),
        thumbnailUrl: uri
            .replace(
              queryParameters: {...uri.queryParameters, 'imwidth': '400'},
            )
            .toString(),
        sourcePageUrl:
            page != null && page.scheme == 'https' && page.host == 'www.rewe.de'
            ? page.toString()
            : reweSearchPage(title).toString(),
        title: title,
        attribution: 'REWE',
      ),
    );
    if (results.length == 40) break;
  }
  if (tiles.isNotEmpty && results.isEmpty) {
    throw const ImageSearchException(
      'Die REWE-Produktbilder konnten nicht gelesen werden.',
    );
  }
  return results;
}
