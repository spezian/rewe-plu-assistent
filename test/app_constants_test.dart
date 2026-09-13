import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/core/app_constants.dart';

void main() {
  test('führt ausschließlich die vorgesehenen Kategorien', () {
    expect(
      <String>[...productCategories, obsoleteCategory],
      const [
        'Obst',
        'Gemüse',
        'Pilze',
        'Schalenfrüchte',
        'Beschädigt',
        'Backwaren',
        'Alkohol',
        'Mobilfunk',
        'Sonstiges',
        'Veraltet',
      ],
    );
  });

  test('benennt die bisherige Nuss-Kategorie um', () {
    expect(normalizeProductCategory('Nüsse'), 'Schalenfrüchte');
    expect(normalizeProductCategory('Obst'), 'Obst');
  });

  test('erkennt neue Supabase Secret Keys', () {
    expect(isSecretSupabaseKey('sb_secret_example'), isTrue);
    expect(isSecretSupabaseKey('sb_publishable_example'), isFalse);
  });

  test('erkennt Legacy Service-Role-JWTs', () {
    expect(isSecretSupabaseKey(_jwtForRole('service_role')), isTrue);
    expect(isSecretSupabaseKey(_jwtForRole('supabase_admin')), isTrue);
    expect(isSecretSupabaseKey(_jwtForRole('anon')), isFalse);
  });
}

String _jwtForRole(String role) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'role': role})))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}
