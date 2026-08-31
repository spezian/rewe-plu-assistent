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
  static const _userAgent = 'RewePLUAssistent/1.0 (eu.dacjan.rewe_plu_assistent; dacjan@mailbox.org)';

  Future<List<RemoteImageSuggestion>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) { return const []; }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'action': 'query',
        'format': 'json',
        'generator': 'images',
        'titles': query,
        'gimlimit': '50',
        'redirects': '1',
        "formatversion": "2",
        'prop': 'imageinfo',
        'iiprop': 'url|mime|extmetadata',
        'iiurlwidth': '900',
      },
    );

    final response = await http.get(uri, headers: {'User-Agent': _userAgent},)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Bildsuche nicht erreichbar (${response.statusCode}).');
    }

    return parseImageSuggestions(json.decode(response.body));
  }
}

List<RemoteImageSuggestion> parseImageSuggestions(Map<String, dynamic> response) {
  if (!response.containsKey("query")) { return const []; }

  final rawImages = response["query"]["pages"];

  final suggestions = <RemoteImageSuggestion>[];
  for (final rawImage in rawImages) {
    final rawImageInfo = rawImage["imageinfo"].first;

    final mime = rawImageInfo['mime'];

    if (mime != "image/jpeg" && mime != "image/png" && mime != "image/gif" && mime != "image/webp" && mime != "image/bmp" && mime != "image/vnd.wap.wbmp") {
      continue;
    }

    final url = rawImageInfo['url'];
    final sourcePage = rawImageInfo['descriptionurl'];

    final rawMetadata = rawImageInfo['extmetadata'];
    final title = rawMetadata['ObjectName']['value'];

    suggestions.add(
      RemoteImageSuggestion(
        title: title,
        imageUrl: _toWikimediaThumbnailUrl(url),
        sourcePageUrl: sourcePage,
        attribution:
            _extractText(rawMetadata, 'Artist') ??
            _extractText(rawMetadata, 'Credit') ?? 'Wikimedia Commons',
        license: rawMetadata['LicenseShortName']['value'] ?? 'Public domain',
      ),
    );
  }

  return suggestions;
}

String? _extractText(Map<String, dynamic> metadata, String key) {
  if (!metadata.containsKey(key)) { return null; }

  RegExp exp = RegExp(r'<[^>]+>([^<]+)');
  RegExpMatch? match = exp.firstMatch(metadata[key]['value']);

  return match?.group(1);
}

String _toWikimediaThumbnailUrl(String originalUrl) {
  final uri = Uri.parse(originalUrl);

  final segments = uri.pathSegments;
  final commonsIndex = segments.indexOf('commons');

  if (commonsIndex == -1 || commonsIndex + 3 >= segments.length) {
    throw FormatException('Invalid Wikimedia Commons image URL');
  }

  final fileName = segments.last;

  // SVG thumbnails are rendered as PNG files.
  final thumbnailName = fileName.toLowerCase().endsWith('.svg')
      ? '330px-$fileName.png'
      : '330px-$fileName';

  final thumbnailSegments = [
    ...segments.sublist(0, commonsIndex + 1),
    'thumb',
    ...segments.sublist(commonsIndex + 1),
    thumbnailName,
  ];

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    pathSegments: thumbnailSegments,
  ).toString();
}
