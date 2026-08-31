import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/data/image_suggestion_service.dart';

void main() {
  test('liest Bild, Quelle und Lizenz aus der Commons-Antwort', () {
    final results = parseImageSuggestions({
      'query': {
        'pages': [
          {
            'title': 'File:Pitahaya fruit.jpg',
            'imageinfo': [
              {
                'mime': 'image/jpeg',
                'url': 'https://upload.wikimedia.org/original.jpg',
                'thumburl': 'https://upload.wikimedia.org/900px.jpg',
                'descriptionurl': 'https://commons.wikimedia.org/wiki/File:x',
                'extmetadata': {
                  'Artist': {'value': '<b>Erika Muster</b>'},
                  'LicenseShortName': {'value': 'CC BY-SA 4.0'},
                },
              },
            ],
          },
        ],
      },
    });

    expect(results.single.title, 'Pitahaya fruit.jpg');
    expect(results.single.imageUrl, contains('900px'));
    expect(results.single.attribution, 'Erika Muster');
    expect(results.single.license, 'CC BY-SA 4.0');
  });
}
