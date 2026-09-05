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

const userAgent = 'RewePLUAssistent/1.0 (eu.dacjan.rewe_plu_assistent; dacjan@mailbox.org)';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const unsplashAccessKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY');

const reweRed = Color(0xffcc071e);

bool get hasSupabaseConfiguration =>
    supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
