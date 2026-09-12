import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_controller.dart';
import '../core/app_constants.dart';
import '../models/market_session.dart';

class MarketAccessScreen extends StatefulWidget {
  const MarketAccessScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<MarketAccessScreen> createState() => _MarketAccessScreenState();
}

class _MarketAccessScreenState extends State<MarketAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _marketNumberController = TextEditingController();
  final _pinController = TextEditingController();
  MarketAccessLevel _accessLevel = MarketAccessLevel.viewer;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _marketNumberController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 64,
                      color: reweDarkRed,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Markt öffnen',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _marketNumberController,
                      autofocus: false,
                      obscureText: true,
                      obscuringCharacter: '•',
                      keyboardType: TextInputType.number,
                      textInputAction: _accessLevel == MarketAccessLevel.editor
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onFieldSubmitted: (_) {
                        if (_accessLevel == MarketAccessLevel.viewer) _submit();
                      },
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Bitte Marktnummer eingeben.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Marktnummer',
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<MarketAccessLevel>(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateColor.fromMap(
                          {
                            WidgetState.selected: reweTealContainer,
                            WidgetState.focused: Colors.white,
                            WidgetState.hovered: Colors.white,
                            WidgetState.disabled: Colors.grey,
                            WidgetState.any: Colors.white
                          }
                        ),
                        foregroundColor: WidgetStateColor.fromMap(
                            {
                              WidgetState.selected: reweDarkTeal,
                              WidgetState.focused: Colors.black,
                              WidgetState.hovered: Colors.black,
                              WidgetState.disabled: Colors.grey,
                              WidgetState.any: Colors.black
                            }
                        ),

                      ),
                      segments: const [
                        ButtonSegment(
                          value: MarketAccessLevel.viewer,
                          icon: Icon(Icons.visibility_outlined),
                          label: Text('Nur ansehen'),
                        ),
                        ButtonSegment(
                          value: MarketAccessLevel.editor,
                          icon: Icon(Icons.edit_outlined),
                          label: Text('Bearbeiten'),
                        ),
                      ],
                      selected: {_accessLevel},
                      onSelectionChanged: _loading
                          ? null
                          : (selection) => setState(() {
                              _accessLevel = selection.single;
                              _error = null;
                              if (_accessLevel == MarketAccessLevel.viewer) {
                                _pinController.clear();
                              }
                            }),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _accessLevel == MarketAccessLevel.viewer
                          ? 'Lesender Zugriff ohne PIN'
                          : 'Änderungen sind nur mit der Markt-PIN möglich.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (_accessLevel == MarketAccessLevel.editor) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _pinController,
                        obscureText: true,
                        obscuringCharacter: '•',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) =>
                            _accessLevel == MarketAccessLevel.editor &&
                                (value == null || value.isEmpty)
                            ? 'Bitte PIN eingeben.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Markt-PIN',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _accessLevel == MarketAccessLevel.viewer
                            ? 'Markt ansehen'
                            : 'Zum Bearbeiten öffnen',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.controller.enterMarket(
        marketNumber: _marketNumberController.text,
        pin: _accessLevel == MarketAccessLevel.editor
            ? _pinController.text
            : null,
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint('Marktzugang fehlgeschlagen: $error');
      setState(() {
        _loading = false;
        _error = marketAccessErrorMessage(error);
      });
    }
  }
}

String marketAccessErrorMessage(Object error) {
  if (error is AuthException) {
    if (error.code == 'anonymous_provider_disabled' ||
        error.message.toLowerCase().contains('anonymous sign-ins')) {
      return 'Anonymer Zugang ist in Supabase noch nicht aktiviert. Aktiviere '
          'ihn unter Authentication → Sign In / Providers.';
    }
    final code = error.code ?? error.statusCode ?? 'AUTH';
    return 'Die anonyme Gerätesitzung konnte nicht gestartet werden. '
        'Fehlercode: $code';
  }

  if (error is PostgrestException) {
    if (error.message.contains('MARKET_ACCESS_DENIED')) {
      return 'Marktnummer oder PIN ist falsch.';
    }
    if (error.code == 'PGRST202' || error.message.contains('schema cache')) {
      return 'Die Markt-Funktion wurde in diesem Supabase-Projekt nicht '
          'gefunden. Führe die aktuelle supabase/schema.sql erneut aus.';
    }
    if (error.code == '42883') {
      return 'Die pgcrypto-Erweiterung ist noch nicht korrekt eingerichtet. '
          'Führe die aktuelle supabase/schema.sql erneut aus.';
    }
    if (error.code == '42501') {
      return 'Supabase verweigert den Aufruf der Markt-Funktion. Führe die '
          'aktuelle supabase/schema.sql erneut aus.';
    }
    return 'Der Datenbankzugang zum Markt ist fehlgeschlagen. Fehlercode: '
        '${error.code ?? 'POSTGREST'}';
  }

  final normalized = error.toString().toLowerCase();
  if (normalized.contains('socketexception') ||
      normalized.contains('clientexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('network')) {
    return 'Supabase ist derzeit nicht erreichbar. Prüfe die '
        'Internetverbindung und versuche es erneut.';
  }
  return 'Markt konnte nicht geöffnet werden. Technischer Fehler: '
      '${error.runtimeType}';
}
