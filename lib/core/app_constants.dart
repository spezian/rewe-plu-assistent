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
const supabaseLoginEmail = String.fromEnvironment('SUPABASE_LOGIN_EMAIL');

bool get hasSupabaseConfiguration =>
    supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
