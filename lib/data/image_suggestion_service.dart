import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_constants.dart';

class RemoteImageSuggestion {
  const RemoteImageSuggestion({
    required this.imageUrl,
    required this.sourcePageUrl,
    this.attribution,
    this.license,
  });

  final String imageUrl;
  final String sourcePageUrl;
  final String? attribution;
  final String? license;
}

class ImageSuggestionService {
  const ImageSuggestionService();

  Future<List<RemoteImageSuggestion>> search(String query) async {
    final uri = Uri.https(
      'api.unsplash.com',
      '/search/photos',
      {
        'page': '1',
        'per_page': '20',
        'query': query,
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Client-ID $unsplashAccessKey',
        'Accept-Version': 'v1',
        if (!kIsWeb) 'User-Agent': userAgent,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Unsplash request failed: ${response.statusCode}',
      );
    }

    final photos = jsonDecode(response.body) as Map<String, dynamic>;

    if (photos["total"] == 0) {
      return [];
    }

    final suggestions = <RemoteImageSuggestion>[];
    for (final photo in photos["results"]) {
      suggestions.add(
          RemoteImageSuggestion(
              imageUrl: photo["urls"]?["small"],
              sourcePageUrl: photo["links"]?["html"],
              attribution: photo["user"]?["name"]
          )
      );
    }
    return suggestions;
  }
}
