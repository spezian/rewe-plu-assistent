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

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const unsplashAccessKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY');

bool get hasSupabaseConfiguration =>
    supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
