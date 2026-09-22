import 'package:flutter_test/flutter_test.dart';
import 'package:rewe_plu_assistent/models/cashier_plan.dart';

void main() {
  final monday = DateTime(2026, 9, 21);
  CashierPlan plan({
    String note = '',
    List<CashierShift> shifts = const [CashierShift(480, 990)],
  }) => CashierPlan({
    'people': {'anna': 'Becker, Anna', 'hidden': 'Verdeckt, Person'},
    'roles': {'anna': 'cashier'},
    'days': {
      '${planDateKey(monday)}|anna': CashierDay(shifts: shifts).toJson(),
      '${planDateKey(monday)}|hidden': CashierDay(note: note).toJson(),
    },
  });

  test(
    'FT from a hidden person closes the entire day without altering the source',
    () {
      final holiday = plan(note: 'FT');
      expect(holiday.freeDayReason(monday), 'FT');
      expect(holiday.day('anna', monday).status, 'Feiertag');
      expect(cashierDayPeople(holiday, monday).single.day.shifts, isEmpty);
      expect(
        (holiday.field('days')['2026-09-21|anna'] as Map)['shifts'],
        isNotEmpty,
      );
      final corrected = holiday.merge({
        'days': {'2026-09-21|hidden': const CashierDay().toJson()},
      });
      expect(corrected.day('anna', monday).shifts, isNotEmpty);
    },
  );

  test(
    'Sundays are free, including the tail of an overnight Saturday shift',
    () {
      final sunday = DateTime(2026, 9, 27);
      final value = plan().merge({
        'days': {
          '2026-09-26|anna': const CashierDay(
            shifts: [CashierShift(1200, 1560)],
          ).toJson(),
          '2026-09-27|anna': const CashierDay(shifts: [CashierShift(600, 960)])
              .toJson(),
        },
      });
      expect(value.freeDayReason(sunday), 'SONNTAG');
      expect(cashierDayPeople(value, sunday).single.day.shifts, isEmpty);
      expect(
        cashierDayPeople(value, sunday).single.day.status,
        'Sonntag · frei',
      );
    },
  );

  test('adult standard blocks use working time after deducting the break', () {
    for (final (span, expected) in [
      (360, 0),
      (361, 30),
      (540, 30),
      (570, 30),
      (571, 45),
      (600, 45),
    ]) {
      expect(
        calculateCashierBreak([CashierShift(0, span)]).duration,
        expected,
        reason: '$span minute shift',
      );
    }
  });

  test('youth standard blocks use 4.5 and 6 hour net thresholds', () {
    for (final (span, expected) in [
      (270, 0),
      (271, 30),
      (300, 30),
      (360, 30),
      (390, 30),
      (391, 60),
      (540, 60),
    ]) {
      expect(
        calculateCashierBreak([CashierShift(0, span)], under18: true).duration,
        expected,
        reason: '$span minute shift',
      );
    }
  });

  test(
    'break placement checks both sides, shift boundaries and youth timing',
    () {
      const shifts = [CashierShift(480, 1020)];
      expect(
        calculateCashierBreak(shifts, start: 840).interval!.label,
        '14:00–14:30',
      );
      expect(calculateCashierBreak(shifts, start: 841).error, contains('6'));
      expect(calculateCashierBreak(shifts, start: 500).error, contains('6'));
      expect(calculateCashierBreak(shifts, start: 480).error, isNotNull);
      expect(calculateCashierBreak(shifts, start: 990).error, isNotNull);
      expect(
        calculateCashierBreak(
          shifts,
          under18: true,
          start: 750,
        ).interval!.label,
        '12:30–13:30',
      );
      expect(
        calculateCashierBreak(shifts, under18: true, start: 751).error,
        contains('4½'),
      );
      expect(
        calculateCashierBreak(shifts, under18: true, start: 530).error,
        contains('eine Stunde'),
      );
      expect(
        calculateCashierBreak(
          const [CashierShift(480, 810)],
          under18: true,
          start: 750,
        ).error,
        contains('eine Stunde'),
      );
    },
  );

  test(
    'split and overlapping shifts are not double counted or bridged by a break',
    () {
      const split = [CashierShift(480, 720), CashierShift(780, 1080)];
      expect(calculateCashierBreak(split, start: 690).error, isNotNull);
      expect(calculateCashierBreak(split, start: 900).interval, isNotNull);
      expect(
        calculateCashierBreak(const [
          CashierShift(480, 840),
          CashierShift(600, 840),
        ]).duration,
        0,
      );
    },
  );

  test(
    'manual breaks survive imports, are recalculated and can be removed',
    () {
      final saved = plan().merge({
        'breaks': {'2026-09-21|anna': 720},
        'under18': {'anna': true},
      });
      expect(saved.people.first.under18, isTrue);
      expect(saved.day('anna', monday).breaks.single.end, 780);
      expect(saved.day('anna', monday).isAvailableAt(730), isFalse);
      expect(saved.day('anna', monday).isAvailableAt(780), isTrue);
      final changed = saved.merge(
        plan(shifts: const [CashierShift(840, 1320)]).data,
      );
      expect(changed.breakStart('anna', monday), 720);
      expect(changed.day('anna', monday).breaks, isEmpty);
      expect(changed.day('anna', monday).breakIssue, isNotNull);
      final removed = saved.merge({
        'breaks': {'2026-09-21|anna': null},
      });
      expect(removed.day('anna', monday).breaks, isEmpty);
      expect(removed.people.first.under18, isTrue);
    },
  );

  test(
    'overnight breaks retain their duration and carry over to the next day',
    () {
      final night = plan(shifts: const [CashierShift(1200, 1740)]).merge({
        'breaks': {'2026-09-21|anna': 1455},
      });
      expect(night.day('anna', monday).breaks.single.label, '00:15–00:45 (+1)');
      final next = cashierDayPeople(night, DateTime(2026, 9, 22)).single.day;
      expect(next.breaks.single.start, 15);
      expect(next.isAvailableAt(30), isFalse);
      expect(next.isAvailableAt(45), isTrue);
    },
  );
}
