import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteImageSuggestion {
  const RemoteImageSuggestion({
    required this.title,
    required this.imageUrl,
    required this.sourcePageUrl,
    this.attribution,
    this.license,
  });

  final String title;
  final String imageUrl;
  final String sourcePageUrl;
  final String? attribution;
  final String? license;
}

class ImageSuggestionService {
  const ImageSuggestionService();

  static const _endpoint = 'https://commons.wikimedia.org/w/api.php';
  static const _userAgent = String.fromEnvironment(
    'WIKIMEDIA_USER_AGENT',
    defaultValue:
        'RewePLUAssistent/1.2 (Android; eu.dacjan.rewe_plu_assistent)',
  );

  Future<List<RemoteImageSuggestion>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'action': 'query',
        'format': 'json',
        'formatversion': '2',
        'generator': 'search',
        'gsrsearch': '$query filetype:bitmap',
        'gsrnamespace': '6',
        'gsrlimit': '12',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|extmetadata',
        'iiurlwidth': '900',
      },
    );
    final response = await http
        .get(
          uri,
          headers: {'User-Agent': _userAgent, 'Api-User-Agent': _userAgent},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Bildsuche nicht erreichbar (${response.statusCode}).');
    }
    return parseImageSuggestions(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

List<RemoteImageSuggestion> parseImageSuggestions(
  Map<String, dynamic> response,
) {
  final pages = response['query'] is Map<String, dynamic>
      ? (response['query'] as Map<String, dynamic>)['pages']
      : null;
  if (pages is! List<dynamic>) return const [];
  final suggestions = <RemoteImageSuggestion>[];
  for (final rawPage in pages) {
    if (rawPage is! Map<String, dynamic>) continue;
    final imageInfoList = rawPage['imageinfo'];
    if (imageInfoList is! List<dynamic> || imageInfoList.isEmpty) continue;
    final imageInfo = imageInfoList.first;
    if (imageInfo is! Map<String, dynamic>) continue;
    final mime = imageInfo['mime']?.toString() ?? '';
    if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) continue;
    final imageUrl = (imageInfo['thumburl'] ?? imageInfo['url'])?.toString();
    final sourcePage = imageInfo['descriptionurl']?.toString();
    if (imageUrl == null || sourcePage == null) continue;
    final metadata = imageInfo['extmetadata'] is Map<String, dynamic>
        ? imageInfo['extmetadata'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawTitle = rawPage['title']?.toString() ?? 'Wikimedia Commons';
    suggestions.add(
      RemoteImageSuggestion(
        title: rawTitle
            .replaceFirst(RegExp(r'^File:'), '')
            .replaceAll('_', ' '),
        imageUrl: imageUrl,
        sourcePageUrl: sourcePage,
        attribution:
            _metadataText(metadata, 'Artist') ??
            _metadataText(metadata, 'Credit'),
        license: _metadataText(metadata, 'LicenseShortName'),
      ),
    );
  }
  return suggestions;
}

String? _metadataText(Map<String, dynamic> metadata, String key) {
  final entry = metadata[key];
  if (entry is! Map<String, dynamic>) return null;
  final value = entry['value']?.toString();
  if (value == null || value.trim().isEmpty) return null;
  return value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
