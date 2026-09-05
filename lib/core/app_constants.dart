import 'dart:convert';

import 'package:flutter/material.dart';

const productCategories = <String>[
  'Obst',
  'Gemüse',
  'Backwaren',
  'Getränke',
  'Molkereiprodukte',
  'Fleisch & Wurst',
  'Tiefkühl',
  'Süßwaren',
  'Haushalt',
  'Aktionsware',
  'Sonstiges',
];

const userAgent =
    'RewePLUAssistent/1.0 (eu.dacjan.rewe_plu_assistent; dacjan@mailbox.org)';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
const supabaseLegacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const unsplashAccessKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY');

const reweRed = Color(0xffcc071e);

String get supabaseClientKey => supabasePublishableKey.trim().isNotEmpty
    ? supabasePublishableKey.trim()
    : supabaseLegacyAnonKey.trim();

String? get supabaseConfigurationError {
  if (supabaseClientKey.isEmpty || !isSecretSupabaseKey(supabaseClientKey)) {
    return null;
  }
  return 'Der konfigurierte Supabase-Key ist ein geheimer Secret-/Service-'
      'Role-Key und darf nicht in der App verwendet werden. Nutze unter '
      'Supabase → Project Settings → API Keys den Publishable Key.';
}

bool get hasSupabaseConfiguration =>
    supabaseUrl.trim().isNotEmpty &&
    supabaseClientKey.isNotEmpty &&
    supabaseConfigurationError == null;

bool isSecretSupabaseKey(String rawKey) {
  final key = rawKey.trim();
  if (key.startsWith('sb_secret_')) return true;

  final parts = key.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return false;
    return const {'service_role', 'supabase_admin'}.contains(payload['role']);
  } on FormatException {
    return false;
  }
}
