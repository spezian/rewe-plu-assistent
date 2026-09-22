import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/data/myplano_import.dart';
import 'package:rewe_plu_assistent/models/cashier_plan.dart';

String exportHtml({
  String month = 'Sep. 2026',
  String? rows,
  int expected = 3,
  int day = 21,
  String weekday = 'Mo',
}) =>
    '''
<html><button id="btn-date-picker" aria-label="$month">$month</button>
<div role="grid"><div role="columnheader" data-field="colHead">Person $expected/$expected</div>
<div role="columnheader" data-field="colDay$day">$day $weekday</div>
${rows ?? '${personRow('Becker, Anna', ['05:00', '14:00'], day: day)}${personRow('Wolf, Ben', ['FREI'], day: day)}${personRow('Klein, Cleo', ['AZ'], day: day)}'}
</div></html>''';

String personRow(
  String name,
  List<String> tokens, {
  int day = 21,
  String suffix = 'current',
}) =>
    '''
<div role="row" data-id="data-row-$name-$suffix"><div role="gridcell" data-field="colHead"><span aria-label="Person $name">$name</span></div>
<div role="gridcell" data-field="colDay$day"><div>${tokens.map((t) => '<p class="task-badge">$t</p>').join()}</div></div></div>''';

void main() {
  MyPlanoImport parse(String value) => parseMyPlanoHtml(
    value,
    fileName: 'plan.html',
    importedAt: DateTime(2026, 9, 21, 10),
  );

  test('reads shifts and distinguishes absence, AZ, and missing data', () {
    final imported = parse(exportHtml());
    final plan = const CashierPlan().merge(imported.patch);
    expect(imported.month, DateTime(2026, 9));
    expect(imported.peopleCount, 3);
    expect(imported.shiftCount, 1);
    expect(
      plan.day('becker, anna', DateTime(2026, 9, 21)).shifts.single.label,
      '05:00–14:00',
    );
    expect(plan.day('wolf, ben', DateTime(2026, 9, 21)).isAbsent, isTrue);
    expect(plan.day('klein, cleo', DateTime(2026, 9, 21)).isAbsent, isTrue);
    expect(plan.day('klein, cleo', DateTime(2026, 9, 21)).status, 'AZ');
    expect(
      plan.day('becker, anna', DateTime(2026, 9, 22)).status,
      'Keine Daten',
    );
    expect(plan.people.every((p) => p.role == CashierRole.hidden), isTrue);
    expect(plan.day('becker, anna', DateTime(2026, 9, 22)).isAbsent, isTrue);
    expect(imported.warnings.join(), isNot(contains('AZ')));
    expect(imported.warnings.join(), isNot(contains('Ohne Zeitangabe')));
  });

  test(
    'FT imports as a free day for everyone without an unknown-code warning',
    () {
      final imported = parse(
        exportHtml(
          rows:
              '${personRow('Becker, Anna', ['08:00', '16:30'])}'
              '${personRow('Klein, Cleo', ['FT'])}',
        ),
      );
      final plan = const CashierPlan().merge(imported.patch);
      expect(
        plan.day('becker, anna', DateTime(2026, 9, 21)).status,
        'Feiertag',
      );
      expect(plan.day('becker, anna', DateTime(2026, 9, 21)).shifts, isEmpty);
      expect(imported.warnings.join(), isNot(contains('unbekannte Kürzel')));
    },
  );

  test(
    'identifies partial exports and ignores groups and non-current rows',
    () {
      final imported = parse(
        exportHtml(
          expected: 103,
          rows:
              '''
      <div role="row" data-id="0"><div data-field="colHead">12345678</div></div>
      ${personRow('Becker, Anna', ['05:00', '14:00'])}
      ${personRow('Becker, Anna', ['06:00', '15:00'], suffix: 'planned')}
    ''',
        ),
      );
      expect(imported.peopleCount, 1);
      expect(imported.warnings.join(), contains('1 von 103'));
      expect(imported.warnings.join(), contains('Nicht alle Tagesfelder'));
      expect(imported.shiftCount, 1);
    },
  );

  test('retains roles and other dates when importing another partial view', () {
    final initial = const CashierPlan().merge(parse(exportHtml()).patch).merge({
      'roles': {'becker, anna': 'cashier', 'wolf, ben': 'manager'},
    });
    final next = parse(
      exportHtml(
        rows: personRow('Becker, Anna', ['09:00', '18:00'], day: 22),
        day: 22,
        weekday: 'Di',
      ),
    );
    final merged = initial.merge(next.patch);
    expect(merged.people.length, 3);
    expect(merged.people.first.role, CashierRole.cashier);
    expect(
      merged.day('becker, anna', DateTime(2026, 9, 21)).shifts.single.start,
      300,
    );
    expect(
      merged.day('becker, anna', DateTime(2026, 9, 22)).shifts.single.start,
      540,
    );
    final clear = merged.merge(
      parse(exportHtml(rows: personRow('Becker, Anna', []))).patch,
    );
    expect(clear.day('becker, anna', DateTime(2026, 9, 21)).shifts, isEmpty);
    expect(clear.people.first.role, CashierRole.cashier);
  });

  test('supports split shifts, overnight shifts, entities and midnight', () {
    final imported = parse(
      exportHtml(
        rows: personRow('Müller &amp; Test, Zoë', [
          '08:00',
          '12:00',
          '20:00',
          '02:00',
        ]),
      ),
    );
    final plan = const CashierPlan().merge(imported.patch).merge({
      'roles': {'müller & test, zoë': 'cashier'},
    });
    final shifts = plan.day('müller & test, zoë', DateTime(2026, 9, 21)).shifts;
    expect(shifts.length, 2);
    expect(shifts.last.end, 1560);
    final next = cashierDayPeople(plan, DateTime(2026, 9, 22)).single;
    expect(next.day.shifts.single.start, 0);
    expect(next.day.shifts.single.end, 120);
    expect(next.day.shifts.single.contains(120), isFalse);
    expect(
      parse(exportHtml(rows: personRow('Test, Anna', ['20:00', '24:00'])))
          .shiftCount,
      1,
    );
  });

  test('rejects missing month, inconsistent weekdays and malformed times', () {
    for (final source in [
      '<html><script>2026</script></html>',
      exportHtml(month: 'September 2025'),
      exportHtml(weekday: 'Di'),
      exportHtml(rows: personRow('Test, Anna', ['25:00', '28:00'])),
      exportHtml(rows: personRow('Test, Anna', ['08:00'])),
      exportHtml(rows: personRow('Test, Anna', ['08:00', '08:00'])),
    ]) {
      expect(() => parse(source), throwsFormatException);
    }
  });

  test(
    'deduplicates a pinned person but rejects conflicting same-name rows',
    () {
      final row = personRow('Test, Anna', ['08:00', '16:00']);
      expect(parse(exportHtml(rows: '$row$row')).shiftCount, 1);
      expect(
        () => parse(
          exportHtml(
            rows: '$row${personRow('Test, Anna', ['09:00', '17:00'])}',
          ),
        ),
        throwsFormatException,
      );
    },
  );

  final realFile = Platform.environment['MYPLANO_HTML'];
  test(
    'validates the supplied MyPlano export without committing personal data',
    () {
      final imported = parse(File(realFile!).readAsStringSync());
      expect(imported.month, DateTime(2026, 9));
      expect(imported.peopleCount, 52);
      expect(imported.expectedPeople, 103);
      expect(imported.shiftCount, 199);
      expect(imported.patch['days'].length, 1560);
      expect(imported.warnings.join(), contains('52 von 103'));
    },
    skip: realFile == null
        ? 'Set MYPLANO_HTML to validate the private original.'
        : false,
  );
}
