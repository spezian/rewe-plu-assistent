import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/data/photo_plan_import.dart';
import 'package:rewe_plu_assistent/models/cashier_plan.dart';

Map<String, dynamic> cell(
  int row,
  int column,
  String text, {
  int width = 1,
  int height = 1,
}) => {
  'rowIndex': row,
  'columnIndex': column,
  'content': text,
  'columnSpan': width,
  'rowSpan': height,
};

Map<String, dynamic> sampleLayout({
  String title = 'Wochenplan KW 41 / 2026',
  List<Map<String, dynamic>>? cells,
}) => {
  'content': '$title\nNicht genehmigt\nPausenplan Anna 10:00 Ben 13:30',
  'tables': [
    {
      'cells':
          cells ??
          [
            cell(0, 0, 'Name', height: 2),
            cell(0, 1, 'Mo, 05.10', width: 2),
            cell(0, 3, 'Di, 06.10', width: 2),
            cell(0, 5, 'AZ Woche', height: 2),
            cell(1, 1, 'Arbeitszeit'),
            cell(1, 2, 'P'),
            cell(1, 3, 'Arbeitszeit'),
            cell(1, 4, 'P'),
            cell(2, 0, 'Becker, Anna'),
            cell(2, 1, '06:00 - 14:00'),
            cell(2, 2, '00:30'),
            cell(2, 3, '09:00 - 18:00'),
            cell(2, 4, '00:30'),
            cell(2, 5, '40:00'),
            cell(3, 0, 'Wolf, Ben'),
            cell(3, 1, 'ABW'),
            cell(3, 2, ''),
            cell(3, 3, ''),
            cell(3, 4, '00:00'),
          ],
    },
  ],
};

void main() {
  test(
    'extracts dated shifts and ABW, ignoring all pauses and weekly totals',
    () {
      final draft = parsePhotoPlanLayout(sampleLayout());
      expect(draft.rows.length, 2);
      expect(draft.selectedCount, 3);
      expect(draft.warnings.single, contains('Nicht genehmigt'));
      final patch = draft.toPatch(
        existing: const CashierPlan(),
        fileName: 'plan.jpg',
      );
      expect(patch.keys.toSet(), {'people', 'days', 'imports'});
      final plan = CashierPlan(patch);
      expect(
        plan.day('becker, anna', DateTime(2026, 10, 5)).shifts.single.label,
        '06:00–14:00',
      );
      expect(
        plan.day('becker, anna', DateTime(2026, 10, 6)).shifts.single.label,
        '09:00–18:00',
      );
      expect(plan.day('wolf, ben', DateTime(2026, 10, 5)).status, 'Abwesend');
      expect(
        (patch['days'] as Map).containsKey('2026-10-06|wolf, ben'),
        isFalse,
      );
      expect(plan.field('breaks'), isEmpty);
      expect(plan.field('days').length, 3);
    },
  );

  test(
    'reimport preserves manual pauses, roles, empty cells and other dates',
    () {
      final initial = CashierPlan({
        'people': {'anna-existing': 'Becker, Anna', 'wolf, ben': 'Wolf, Ben'},
        'roles': {'anna-existing': 'cashier'},
        'breaks': {'2026-10-05|anna-existing': 600},
        'under18': {'anna-existing': true},
        'days': {
          '2026-10-06|wolf, ben': const CashierDay(
            shifts: [CashierShift(600, 900)],
          ).toJson(),
          '2026-10-07|anna-existing': const CashierDay(
            shifts: [CashierShift(600, 900)],
          ).toJson(),
        },
      });
      final patch = parsePhotoPlanLayout(sampleLayout())
          .toPatch(existing: initial, fileName: 'plan.jpg');
      final merged = initial.merge(patch);
      expect(merged.people.length, 2);
      expect(merged.breakStart('anna-existing', DateTime(2026, 10, 5)), 600);
      expect(merged.people.first.role, CashierRole.cashier);
      expect(merged.people.first.under18, isTrue);
      expect(
        merged.day('wolf, ben', DateTime(2026, 10, 6)).shifts.single.start,
        600,
      );
      expect(
        merged.day('anna-existing', DateTime(2026, 10, 7)).shifts.single.start,
        600,
      );
    },
  );

  test(
    'unknown, merged and malformed entries need correction or stay excluded',
    () {
      final layout = sampleLayout();
      final cells = (layout['tables'] as List).single['cells'] as List;
      cells.add(cell(4, 0, 'Test, Cleo'));
      cells.add(cell(4, 1, '06:00 - 14:O0'));
      cells.add(cell(4, 3, '08:00 - 17:00', width: 2));
      final draft = parsePhotoPlanLayout(layout);
      final row = draft.rows.last;
      expect(
        row.cells.every((entry) => !entry.selected && entry.error != null),
        isTrue,
      );
      row.cells.first.text = '06:00 - 14:00';
      row.cells.first.selected = true;
      expect(draft.selectedCount, 4);
      final patch = draft.toPatch(
        existing: const CashierPlan(),
        fileName: 'plan.jpg',
      );
      expect(
        (patch['days'] as Map).containsKey('2026-10-05|test, cleo'),
        isTrue,
      );
      expect(
        (patch['days'] as Map).containsKey('2026-10-06|test, cleo'),
        isFalse,
      );
    },
  );

  test('rejects missing year, wrong weekday and wrong week', () {
    for (final title in [
      'Wochenplan',
      'Wochenplan KW 40 / 2026',
      'Wochenplan KW 41 / 2025',
    ]) {
      expect(
        () => parsePhotoPlanLayout(sampleLayout(title: title)),
        throwsFormatException,
      );
    }
    final layout = sampleLayout();
    (layout['tables'][0]['cells'][1] as Map)['content'] = 'Di, 05.10';
    expect(() => parsePhotoPlanLayout(layout), throwsFormatException);
  });

  test('resolves ISO week across years and records both calendar months', () {
    final layout = sampleLayout(
      title: 'KW 53 / 2026',
      cells: [
        cell(0, 0, 'Name'),
        cell(0, 1, 'Do, 31.12'),
        cell(0, 2, 'Fr, 01.01'),
        cell(1, 0, 'Becker, Anna'),
        cell(1, 1, '08:00–16:00'),
        cell(1, 2, 'ABW'),
      ],
    );
    final draft = parsePhotoPlanLayout(layout);
    expect(draft.rows.single.cells.map((entry) => entry.date), [
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 1),
    ]);
    final patch = draft.toPatch(
      existing: const CashierPlan(),
      fileName: 'plan.jpg',
    );
    expect((patch['imports'] as Map).keys.toSet(), {'2026-12', '2027-01'});
  });

  test(
    'full dated columns work without week title and reversed names match',
    () {
      final draft = parsePhotoPlanLayout(
        sampleLayout(
          title: '',
          cells: [
            cell(0, 0, 'Name'),
            cell(0, 1, '05.10.2026'),
            cell(1, 0, 'Anna Becker'),
            cell(1, 1, '08:00–16:00'),
          ],
        ),
      );
      final patch = draft.toPatch(
        existing: const CashierPlan({
          'people': {'known-id': 'Becker, Anna'},
        }),
        fileName: 'plan.png',
      );
      expect((patch['people'] as Map).keys.single, 'known-id');
    },
  );

  test('never mistakes a dated pause column for an Arbeitszeit column', () {
    final layout = sampleLayout(
      cells: [
        cell(0, 0, 'Name', height: 2),
        cell(0, 1, 'Mo, 05.10'),
        cell(1, 1, 'P'),
        cell(2, 0, 'Becker, Anna'),
        cell(2, 1, '10:00–10:30'),
      ],
    );
    expect(() => parsePhotoPlanLayout(layout), throwsFormatException);
  });

  test(
    'multiple plans and duplicate person/day cannot overwrite one another',
    () {
      expect(
        () => parsePhotoPlanLayout(
          sampleLayout(title: 'KW 41 / 2026 KW 42 / 2026'),
        ),
        throwsFormatException,
      );
      final draft = parsePhotoPlanLayout(sampleLayout());
      draft.rows.last.name = draft.rows.first.name;
      expect(
        () =>
            draft.toPatch(existing: const CashierPlan(), fileName: 'plan.jpg'),
        throwsFormatException,
      );
    },
  );

  test(
    'day validation handles split/overnight shifts and explicit absence',
    () {
      final day = parsePhotoPlanDay('08:00–12:00; 20:00-02:00');
      expect(day.shifts.length, 2);
      expect(day.shifts.last.end, 1560);
      expect(parsePhotoPlanDay('20:00-24:00').shifts.single.end, 1440);
      expect(parsePhotoPlanDay('abw').note, 'Abwesend');
      for (final text in [
        '',
        '00:30',
        '08:00',
        '08:60–12:00',
        '08:00-24:01',
        '24:00–25:00',
        '08:00–08:00',
        '06:00-04:00',
        '08:00-12:00; 11:00-13:00',
      ]) {
        expect(
          () => parsePhotoPlanDay(text),
          throwsFormatException,
          reason: text,
        );
      }
    },
  );
}
