import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/app_constants.dart';
import 'data/product_repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await _enableWakelock();

  SupabaseClient? supabaseClient;
  if (hasSupabaseConfiguration) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseClientKey,
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

Future<void> _enableWakelock() async {
  try {
    await WakelockPlus.enable();
  } catch (_) {
    // Browsers may reject wake locks outside a secure/visible context. The app
    // should still start, and the lifecycle callback will try again on resume.
  }
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
    if (state == AppLifecycleState.resumed) unawaited(_enableWakelock());
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
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(centerTitle: false),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: reweRed,
            selectionColor: Colors.grey[400]!,
            selectionHandleColor: reweRed,
          ),
          cardTheme: const CardThemeData(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: Colors.grey[200]!,
            selectedColor: reweRed,
            labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: Colors.black,
            ),
            secondaryLabelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: Colors.white,
                ),
            checkmarkColor: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
