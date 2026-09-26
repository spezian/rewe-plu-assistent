import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/app_controller.dart';
import 'package:rewe_plu_assistent/app_scope.dart';
import 'package:rewe_plu_assistent/data/product_repository.dart';
import 'package:rewe_plu_assistent/models/cashier_plan.dart';
import 'package:rewe_plu_assistent/screens/cashier_plan_screen.dart';
import 'package:rewe_plu_assistent/screens/home_screen.dart';

CashierPlan samplePlan() {
  final date = DateTime(2026, 9, 21);
  final people = {
    'anna': 'Becker, Anna',
    'ben': 'Wolf, Ben',
    'cleo': 'Klein, Cleo',
    'dana': 'Sommer, Dana',
    'emil': 'Fischer, Emil',
    'hidden': 'Unsichtbar, Person',
  };
  return CashierPlan({
    'people': people,
    'roles': {
      'anna': 'cashier',
      'ben': 'cashier',
      'cleo': 'manager',
      'dana': 'cashier',
      'emil': 'cashier',
    },
    'days': {
      '${planDateKey(date)}|anna': const CashierDay(
        shifts: [CashierShift(360, 840)],
      ).toJson(),
      '${planDateKey(date)}|ben': const CashierDay(
        shifts: [CashierShift(840, 1320)],
      ).toJson(),
      '${planDateKey(date)}|cleo': const CashierDay(
        shifts: [CashierShift(480, 1020)],
      ).toJson(),
      '${planDateKey(date)}|dana': const CashierDay(note: 'FREI').toJson(),
      '${planDateKey(date)}|emil': const CashierDay(note: 'AZ').toJson(),
      '${planDateKey(date)}|hidden': const CashierDay(
        shifts: [CashierShift(300, 1350)],
      ).toJson(),
    },
    'imports': {
      '2026-09': {
        'fileName': 'myplano.html',
        'importedAt': '2026-09-21T08:30:00',
        'warnings': <String>[],
      },
    },
  });
}

class PlanController extends AppController {
  PlanController({bool canEdit = false, CashierPlan? plan})
    : editable = canEdit,
      _plan = plan ?? samplePlan(),
      super(ProductRepository());
  final bool editable;
  CashierPlan _plan;
  @override
  bool get canEdit => editable;
  @override
  CashierPlan get cashierPlan => _plan;
  @override
  Future<void> saveCashierPlanPatch(Map<String, dynamic> patch) async {
    _plan = _plan.merge(patch);
    notifyListeners();
  }
}

void main() {
  setUpAll(() async {
    final fontPath = Platform.environment['CASHIER_PLAN_FONT'];
    if (fontPath == null) return;
    final font = FontLoader('Roboto')
      ..addFont(
        File(fontPath).readAsBytes().then((v) => ByteData.sublistView(v)),
      );
    await font.load();
    final iconPath = Platform.environment['CASHIER_PLAN_ICONS'];
    if (iconPath != null) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(iconPath).readAsBytes().then((v) => ByteData.sublistView(v)),
        );
      await icons.load();
    }
  });
  Future<void> mount(
    WidgetTester tester,
    PlanController controller, {
    double width = 390,
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: Platform.environment['CASHIER_PLAN_FONT'] == null
                ? null
                : 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFCC071E),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: AppScope(
            controller: controller,
            child: Scaffold(
              appBar: AppBar(title: const Text('Kassenplan')),
              body: CashierPlanScreen(now: () => DateTime(2026, 9, 21, 13, 45)),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 2,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.list_alt_outlined),
                    label: 'Produkte',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search),
                    label: 'Suche',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: 'Kassenplan',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mobile day view filters working people and reveals absence separately',
    (tester) async {
      await mount(tester, PlanController());
      expect(find.text('2 laut Plan verfügbar'), findsOneWidget);
      expect(find.text('Nächster Wechsel · 14:00'), findsOneWidget);
      expect(find.text('Kommt: Ben Wolf'), findsOneWidget);
      expect(find.text('Geht: Anna Becker'), findsOneWidget);
      expect(find.text('Person Unsichtbar'), findsNothing);
      expect(find.text('Dana Sommer'), findsNothing);
      await tester.scrollUntilVisible(find.text('Jetzt da').first, 150);
      await tester.tap(find.text('Jetzt da').first);
      await tester.pumpAndSettle();
      expect(find.text('Ben Wolf'), findsNothing);
      await tester.scrollUntilVisible(find.text('Anna Becker'), 150);
      expect(find.text('Anna Becker'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Marktleitung'), -150);
      await tester.tap(find.text('Marktleitung'));
      await tester.pumpAndSettle();
      expect(find.text('Anna Becker'), findsNothing);
      await tester.scrollUntilVisible(find.text('Cleo Klein'), 150);
      expect(find.text('Cleo Klein'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small mobile screen supports larger text, absence and date changes',
    (tester) async {
      final plan = samplePlan().merge({
        'imports': {
          '2026-09': {
            'fileName': 'myplano.html',
            'warnings': [
              '1 Einträge enthalten Kürzel ohne Arbeitszeiten (z. B. AZ). Sie erscheinen unter „Ohne Zeitangabe“.',
            ],
          },
        },
      });
      await mount(tester, PlanController(plan: plan), width: 320, scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Abwesend / frei (2)'), 250);
      await tester.tap(find.text('Abwesend / frei (2)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('AZ'), 150);
      expect(find.text('Emil Fischer'), findsOneWidget);
      expect(find.textContaining('ohne Zeitangabe'), findsNothing);
      await tester.scrollUntilVisible(find.text('Dana Sommer'), 150);
      expect(find.text('Frei'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('MyPlano · Importdetails'),
        150,
      );
      await tester.tap(find.text('MyPlano · Importdetails'));
      await tester.pumpAndSettle();
      expect(find.textContaining('(z. B. AZ)'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byTooltip('Nächster Tag'), -400);
      await tester.tap(find.byTooltip('Nächster Tag'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Keine Schichtzeiten vorhanden'),
        200,
      );
      expect(find.text('Keine Schichtzeiten vorhanden'), findsOneWidget);
      expect(find.text('2 laut Plan verfügbar'), findsNothing);
      await tester.scrollUntilVisible(find.text('Abwesend / frei (5)'), 150);
      await tester.tap(find.text('Abwesend / frei (5)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Keine Daten').first, 150);
      expect(find.text('Keine Daten'), findsWidgets);
      expect(find.textContaining('Ohne Zeitangabe'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('viewer has no import or team controls', (tester) async {
    final controller = PlanController();
    await mount(tester, controller);
    expect(find.byTooltip('Plan importieren'), findsNothing);
    expect(find.byTooltip('Team & Rollen'), findsNothing);
    expect(find.byTooltip('Pause für Anna Becker'), findsNothing);
    await tester.scrollUntilVisible(find.text('Anna Becker'), 200);
    expect(find.textContaining('Pause noch offen'), findsNothing);
    await controller.saveCashierPlanPatch({
      'breaks': {'2026-09-21|anna': 600, '2026-09-21|ben': 600},
    });
    await tester.pumpAndSettle();
    expect(find.text('Pause 10:00–10:30 · 30 Min.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ben Wolf'), 200);
    expect(find.textContaining('Pause noch offen'), findsNothing);
    expect(find.textContaining('Pause prüfen'), findsNothing);
  });

  testWidgets('editor chooses between HTML and photo import', (tester) async {
    await mount(tester, PlanController(canEdit: true));
    await tester.tap(find.byTooltip('Plan importieren'));
    await tester.pumpAndSettle();
    expect(find.text('MyPlano-HTML importieren'), findsOneWidget);
    expect(find.text('Planfoto importieren'), findsOneWidget);
    expect(find.text('JPG oder PNG · Schichten ohne Pausen'), findsOneWidget);
  });

  testWidgets(
    'editor enters, changes and removes an automatically calculated break',
    (tester) async {
      final controller = PlanController(canEdit: true);
      await mount(tester, controller, width: 320, scale: 1.3);
      await tester.scrollUntilVisible(
        find.byTooltip('Pause für Anna Becker'),
        200,
      );
      expect(find.textContaining('Pause noch offen'), findsWidgets);
      await tester.tap(find.byTooltip('Pause für Anna Becker'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12:30');
      await tester.pumpAndSettle();
      expect(find.textContaining('Maximal 6 Stunden'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Speichern'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '10:00');
      await tester.pumpAndSettle();
      expect(find.text('30 Minuten Pause · 10:00–10:30'), findsOneWidget);
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(
        controller.cashierPlan.breakStart('anna', DateTime(2026, 9, 21)),
        600,
      );
      expect(find.text('Pause 10:00–10:30 · 30 Min.'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause für Anna Becker'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '10:30');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(
        controller.cashierPlan.breakStart('anna', DateTime(2026, 9, 21)),
        630,
      );
      await tester.tap(find.byTooltip('Pause für Anna Becker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause entfernen'));
      await tester.pumpAndSettle();
      expect(
        controller.cashierPlan.breakStart('anna', DateTime(2026, 9, 21)),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'youth setting changes break duration and is saved with team roles',
    (tester) async {
      final controller = PlanController(canEdit: true);
      await mount(tester, controller);
      await tester.tap(find.byTooltip('Team & Rollen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Becker');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zuordnung speichern'));
      await tester.pumpAndSettle();
      expect(
        controller.cashierPlan.people.firstWhere((p) => p.id == 'anna').under18,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Pause für Anna Becker'),
        200,
      );
      await tester.tap(find.byTooltip('Pause für Anna Becker'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '10:00');
      await tester.pumpAndSettle();
      expect(find.text('60 Minuten Pause · 10:00–11:00'), findsOneWidget);
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(
        controller.cashierPlan
            .day('anna', DateTime(2026, 9, 21))
            .breaks
            .single
            .end,
        660,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'active breaks reduce availability and appear in the next change',
    (tester) async {
      final plan = samplePlan().merge({
        'breaks': {'2026-09-21|cleo': 810},
      });
      await mount(tester, PlanController(plan: plan));
      expect(find.text('1 laut Plan verfügbar'), findsOneWidget);
      expect(find.textContaining('1 in Pause'), findsOneWidget);
      expect(find.text('Zurück aus Pause: Cleo Klein'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('In Pause bis 14:00'),
        200,
      );
      expect(find.textContaining('In Pause bis 14:00'), findsOneWidget);
    },
  );

  testWidgets('market-wide holiday hides shifts and break editing', (
    tester,
  ) async {
    final plan = samplePlan().merge({
      'days': {'2026-09-21|hidden': const CashierDay(note: 'FT').toJson()},
    });
    await mount(tester, PlanController(canEdit: true, plan: plan));
    expect(find.text('Feiertag · alle frei'), findsOneWidget);
    expect(find.text('2 laut Plan verfügbar'), findsNothing);
    expect(find.byTooltip('Pause für Anna Becker'), findsNothing);
    await tester.scrollUntilVisible(find.text('Abwesend / frei (5)'), 200);
    await tester.tap(find.text('Abwesend / frei (5)'));
    await tester.pumpAndSettle();
    expect(find.text('Feiertag'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor can search and persist role changes', (tester) async {
    final controller = PlanController(canEdit: true);
    await mount(tester, controller);
    await tester.tap(find.byTooltip('Team & Rollen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsichtbar');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<CashierRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marktleiter').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zuordnung speichern'));
    await tester.pumpAndSettle();
    expect(
      controller.cashierPlan.people.firstWhere((p) => p.id == 'hidden').role,
      CashierRole.manager,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation opens the schedule without a product add button', (
    tester,
  ) async {
    final controller = PlanController(canEdit: true);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(controller: controller, child: const HomeScreen()),
      ),
    );
    await tester.tap(find.text('Kassenplan'));
    await tester.pumpAndSettle();
    expect(find.text('Dienstübersicht'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  final screenshot = Platform.environment['CASHIER_PLAN_SCREENSHOT'];
  testWidgets('renders the mobile preview', (tester) async {
    final boundary = GlobalKey();
    await mount(
      tester,
      PlanController(
        canEdit: true,
        plan: samplePlan().merge({
          'under18': {'anna': true},
          'breaks': {'2026-09-21|anna': 600, '2026-09-21|cleo': 810},
        }),
      ),
      boundary: boundary,
    );
    Future<void> capture(String path) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture(screenshot!);
    await tester.tap(find.byTooltip('Pause für Cleo Klein'));
    await tester.pumpAndSettle();
    await capture(screenshot.replaceFirst(RegExp(r'\.png$'), '-dialog.png'));
    expect(tester.takeException(), isNull);
  }, skip: screenshot == null);
}
