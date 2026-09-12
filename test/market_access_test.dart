import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/app_controller.dart';
import 'package:rewe_plu_assistent/data/product_repository.dart';
import 'package:rewe_plu_assistent/models/market_session.dart';
import 'package:rewe_plu_assistent/screens/market_access_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('liest Viewer- und Editor-Sitzungen aus der RPC-Antwort', () {
    final viewer = MarketSession.fromRpc({
      'market_id': 'market-a',
      'access_level': 'viewer',
    });
    final editor = MarketSession.fromRpc({
      'market_id': 'market-b',
      'access_level': 'editor',
    });

    expect(viewer.canEdit, isFalse);
    expect(editor.canEdit, isTrue);
  });

  test('erklärt deaktivierte anonyme Supabase-Anmeldung konkret', () {
    const error = AuthApiException(
      'Anonymous sign-ins are disabled',
      statusCode: '422',
      code: 'anonymous_provider_disabled',
    );

    expect(
      marketAccessErrorMessage(error),
      contains('Authentication → Sign In / Providers'),
    );
  });

  test('erklärt fehlende RPC-Funktion konkret', () {
    const error = PostgrestException(
      message: 'Could not find the function public.enter_market',
      code: 'PGRST202',
    );

    expect(marketAccessErrorMessage(error), contains('schema.sql'));
  });

  testWidgets('zeigt keine Markt-Auswahl und verlangt PIN nur zum Bearbeiten', (
    tester,
  ) async {
    final controller = AppController(ProductRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MarketAccessScreen(controller: controller)),
    );

    expect(find.text('Markt öffnen'), findsOneWidget);
    expect(
      find.textContaining('nicht angezeigt oder vorgeschlagen'),
      findsOneWidget,
    );
    expect(find.text('Markt-PIN'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );

    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();

    expect(find.text('Markt-PIN'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    for (final field in tester.widgetList<EditableText>(
      find.byType(EditableText),
    )) {
      expect(field.obscureText, isTrue);
    }
  });
}
