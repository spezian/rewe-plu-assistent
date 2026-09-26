import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rewe_plu_assistent/data/photo_plan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'photo_plan_import_test.dart' show sampleLayout;

void main() {
  test(
    'sends photo bytes and market context to the protected function',
    () async {
      final bytes = Uint8List.fromList([255, 216, 255, 1]);
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/functions/v1/parse-plan-photo');
          expect(request.headers['x-market-id'], 'market-id');
          expect(request.headers['content-type'], 'image/jpeg');
          expect(request.bodyBytes, bytes);
          return http.Response(
            jsonEncode(sampleLayout()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await recognizePlanPhoto(
        client: client,
        marketId: 'market-id',
        bytes: bytes,
      );
      expect(result.selectedCount, 3);
    },
  );

  test(
    'surfaces setup failures and rejects invalid images before uploading',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'error': 'Die Azure-Fotoerkennung ist noch nicht eingerichtet.',
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        recognizePlanPhoto(
          client: client,
          marketId: 'market',
          bytes: Uint8List(10),
        ),
        throwsFormatException,
      );
      expect(requests, 0);
      await expectLater(
        recognizePlanPhoto(
          client: client,
          marketId: 'market',
          bytes: Uint8List.fromList([255, 216, 255]),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('nicht eingerichtet'),
          ),
        ),
      );
    },
  );
}
