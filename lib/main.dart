import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/app_constants.dart';
import 'data/product_repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await WakelockPlus.enable();
  } catch (_) {
    // Nicht jeder Browser unterstützt die Screen Wake Lock API.
  }

  SupabaseClient? supabaseClient;
  if (hasSupabaseConfiguration) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      supabaseClient = Supabase.instance.client;
    } catch (_) {
      // Die lokale App muss auch bei einer fehlerhaften Cloud-Konfiguration starten.
    }
  }

  final controller = AppController(
    ProductRepository(supabaseClient: supabaseClient),
  );
  await controller.initialize();
  runApp(RewePluApp(controller: controller));
}

class RewePluApp extends StatefulWidget {
  const RewePluApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<RewePluApp> createState() => _RewePluAppState();
}

class _RewePluAppState extends State<RewePluApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable().catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFCC071E),
      brightness: Brightness.light,
    );
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PLU Assistent',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: const Color(0xFFF8F8F8),
          appBarTheme: const AppBarTheme(centerTitle: false),
          cardTheme: const CardThemeData(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
