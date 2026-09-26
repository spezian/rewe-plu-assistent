import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rewe_plu_assistent/data/photo_plan_import.dart';
import 'package:rewe_plu_assistent/models/cashier_plan.dart';
import 'package:rewe_plu_assistent/screens/photo_plan_review_screen.dart';

void main() {
  setUpAll(() async {
    final fontPath = Platform.environment['PHOTO_PLAN_FONT'];
    if (fontPath == null) return;
    await (FontLoader('Roboto')..addFont(
          File(fontPath)
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
    final icons = Platform.environment['PHOTO_PLAN_ICONS'];
    if (icons != null) {
      await (FontLoader('MaterialIcons')..addFont(
            File(icons)
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
    }
  });
  final existing = CashierPlan({
    'people': {'anna': 'Becker, Anna'},
    'roles': {'anna': 'cashier'},
    'breaks': {'2026-10-05|anna': 600},
    'days': {
      '2026-10-05|anna': const CashierDay(shifts: [CashierShift(480, 960)])
          .toJson(),
    },
  });
  PhotoPlanImport draft() => PhotoPlanImport(
    rows: [
      PhotoPlanRow('Becker, Anna', [
        PhotoPlanCell(DateTime(2026, 10, 5), '06:00–14:00', selected: true),
        PhotoPlanCell(DateTime(2026, 10, 6), '09:00–18:O0'),
        PhotoPlanCell(DateTime(2026, 10, 7), ''),
      ]),
    ],
    warnings: ['Auf dem Foto steht „Nicht genehmigt“.'],
  );
  final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
  );

  Future<void> mount(
    WidgetTester tester,
    PhotoPlanImport import,
    void Function(Map<String, dynamic>?) result, {
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: Platform.environment['PHOTO_PLAN_FONT'] == null
                ? null
                : 'Roboto',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result(
                  await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => PhotoPlanReviewScreen(
                        draft: import,
                        existing: existing,
                        fileName: 'plan.jpg',
                        photo: photo,
                      ),
                    ),
                  ),
                ),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'review shows conflicts, validates edits and returns only selected days',
    (tester) async {
      Map<String, dynamic>? patch;
      final boundary = GlobalKey();
      await mount(
        tester,
        draft(),
        (value) => patch = value,
        boundary: boundary,
      );
      expect(find.text('1 Eintrag übernehmen'), findsOneWidget);
      await tester.tap(find.text('Becker, Anna'));
      await tester.pumpAndSettle();
      expect(find.text('Ersetzt: 08:00–16:00'), findsOneWidget);
      final screenshot = Platform.environment['PHOTO_PLAN_PREVIEW'];
      if (screenshot != null) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(screenshot).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final edit = find.byTooltip('Eintrag bearbeiten').at(1);
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anwenden'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '09:00–18:00');
      await tester.tap(find.text('Anwenden'));
      await tester.pumpAndSettle();
      expect(find.text('2 Einträge übernehmen'), findsOneWidget);
      await tester.tap(find.text('2 Einträge übernehmen'));
      await tester.pumpAndSettle();
      expect(patch, isNotNull);
      expect((patch!['days'] as Map).length, 2);
      expect(patch!.containsKey('breaks'), isFalse);
      expect(
        existing.merge(patch!).breakStart('anna', DateTime(2026, 10, 5)),
        600,
      );
    },
  );

  testWidgets('correcting a name maps to the existing person and roles', (
    tester,
  ) async {
    final import = draft()..rows.first.name = 'Becker, Anma';
    Map<String, dynamic>? patch;
    await mount(tester, import, (value) => patch = value);
    expect(find.textContaining('Neue Person'), findsOneWidget);
    await tester.tap(find.text('Becker, Anma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Person zuordnen / Namen ändern'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Becker, Anna');
    await tester.tap(find.text('Anwenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Eintrag übernehmen'));
    await tester.pumpAndSettle();
    expect((patch!['people'] as Map).keys.single, 'anna');
    expect(existing.merge(patch!).people.single.role, CashierRole.cashier);
  });

  testWidgets('cancel returns no patch and deselection disables importing', (
    tester,
  ) async {
    var completed = false;
    Map<String, dynamic>? patch;
    await mount(tester, draft(), (value) {
      completed = true;
      patch = value;
    });
    await tester.tap(find.text('Becker, Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '0 Einträge übernehmen'),
    );
    expect(button.onPressed, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(patch, isNull);
  });

  testWidgets('review supports enlarged text on a phone', (tester) async {
    await mount(tester, draft(), (_) {}, scale: 1.5);
    await tester.scrollUntilVisible(find.text('Becker, Anna'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Becker, Anna'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
