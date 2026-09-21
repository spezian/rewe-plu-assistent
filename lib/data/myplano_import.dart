import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../models/cashier_plan.dart';

class MyPlanoImport {
  const MyPlanoImport({
    required this.month,
    required this.peopleCount,
    required this.shiftCount,
    required this.expectedPeople,
    required this.warnings,
    required this.patch,
  });
  final DateTime month;
  final int peopleCount;
  final int shiftCount;
  final int? expectedPeople;
  final List<String> warnings;
  final Map<String, dynamic> patch;
}

/// Reads inert HTML only: no scripts, styles, resources or links are executed.
MyPlanoImport parseMyPlanoHtml(
  String source, {
  required String fileName,
  DateTime? importedAt,
}) {
  if (source.length > 15 * 1024 * 1024) {
    throw const FormatException('Die HTML-Datei ist zu groß (maximal 15 MB).');
  }
  final document = html.parse(source);
  final picker = document.querySelector('#btn-date-picker');
  final label = picker?.attributes['aria-label'] ?? picker?.text ?? '';
  final month = _parseMonth(label);
  final grid = document.querySelector('[role="grid"]');
  if (grid == null) {
    throw const FormatException(
      'Kein MyPlano-Gruppenkalender gefunden. Bitte die geladene Kalenderansicht als HTML speichern.',
    );
  }
  final countText =
      grid.querySelector('[role="columnheader"][data-field="colHead"]')?.text ??
      '';
  final countMatch = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(countText);
  final expected = countMatch == null ? null : int.parse(countMatch[1]!);
  final total = countMatch == null ? null : int.parse(countMatch[2]!);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final headerDays = <int>{};
  const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  for (final header in grid.querySelectorAll(
    '[role="columnheader"][data-field]',
  )) {
    final match = RegExp(r'^colDay(\d+)$')
        .firstMatch(header.attributes['data-field']!);
    if (match == null) continue;
    final day = int.parse(match[1]!);
    if (day < 1 || day > daysInMonth) {
      throw const FormatException(
        'Die Tage passen nicht zum ausgewählten Monat.',
      );
    }
    final weekday = RegExp(r'\b(Mo|Di|Mi|Do|Fr|Sa|So)\b')
        .firstMatch(header.text)?[1];
    if (weekday != null &&
        weekday !=
            weekdays[DateTime(month.year, month.month, day).weekday - 1]) {
      throw const FormatException(
        'Monat und Wochentage im Export widersprechen sich. Bitte die HTML-Datei erneut speichern.',
      );
    }
    headerDays.add(day);
  }
  if (headerDays.isEmpty) {
    throw const FormatException('Keine Tages-Spalten gefunden.');
  }
  final timestamp = importedAt ?? DateTime.now();
  final people = <String, dynamic>{};
  final days = <String, dynamic>{};
  var shiftCount = 0;
  var incompleteRows = false;
  var unknownCount = 0;
  for (final row in grid.querySelectorAll('[role="row"][data-id]')) {
    final id = row.attributes['data-id']!;
    if (!id.startsWith('data-row-') || !id.endsWith('-current')) continue;
    final head = row.querySelector('[data-field="colHead"]');
    if (head == null) continue;
    final personLabel = head
        .querySelector('[aria-label^="Person "]')
        ?.attributes['aria-label'];
    final name = (personLabel?.substring(7) ?? head.text).trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (name.isEmpty) continue;
    final personId = planPersonId(name);
    people[personId] = name;
    final rowDays = <int>{};
    for (final cell in row.querySelectorAll('[role="gridcell"][data-field]')) {
      final match = RegExp(r'^colDay(\d+)$')
          .firstMatch(cell.attributes['data-field']!);
      if (match == null) continue;
      final day = int.parse(match[1]!);
      if (!headerDays.contains(day)) continue;
      rowDays.add(day);
      final parsed = _parseDay(cell, timestamp);
      final key =
          '${planDateKey(DateTime(month.year, month.month, day))}|$personId';
      // MyPlano may repeat the signed-in person above their normal group.
      final existing = days[key];
      if (existing != null) {
        final old = CashierDay.fromJson(
          Map<String, dynamic>.from(existing as Map),
        );
        if (old.shifts.map((s) => s.label).join() !=
                parsed.shifts.map((s) => s.label).join() ||
            old.note != parsed.note) {
          throw FormatException(
            'Widersprüchliche Einträge für $name am $day. Bitte den Export prüfen.',
          );
        }
        continue;
      }
      days[key] = parsed.toJson();
      shiftCount += parsed.shifts.length;
      if (parsed.shifts.isEmpty && !parsed.isAbsent && parsed.note.isNotEmpty) {
        unknownCount++;
      }
    }
    if (rowDays.length < daysInMonth) incompleteRows = true;
  }
  if (people.isEmpty) {
    throw const FormatException(
      'Keine aktuellen Personenzeilen gefunden. Bitte den MyPlano-Gruppenkalender exportieren.',
    );
  }
  final warnings = <String>[
    if (expected != null && people.length < expected)
      'Nur ${people.length} von $expected Personen sind in der HTML-Datei enthalten. MyPlano speichert möglicherweise nur geladene Zeilen. Weitere Ausschnitte können ergänzend importiert werden.',
    if (expected != null && total != null && expected < total)
      'In MyPlano war ein Personenfilter aktiv ($expected von $total Personen).',
    if (headerDays.length < daysInMonth || incompleteRows) 'Nicht alle Tagesfelder sind enthalten. Fehlende Felder bleiben unverändert; ohne früheren Import gelten sie als „Keine Daten“.',
    if (unknownCount > 0)
      '$unknownCount Einträge enthalten unbekannte Kürzel ohne Arbeitszeiten. Sie erscheinen unter „Ohne Zeitangabe“.',
  ];
  return MyPlanoImport(
    month: month,
    peopleCount: people.length,
    shiftCount: shiftCount,
    expectedPeople: expected,
    warnings: warnings,
    patch: {
      'people': people,
      'days': days,
      'imports': {
        planMonthKey(month): {
          'fileName': fileName,
          'importedAt': timestamp.toIso8601String(),
          'peopleCount': people.length,
          'expectedPeople': expected,
          'warnings': warnings,
        },
      },
    },
  );
}

DateTime _parseMonth(String label) {
  const names = {
    'jan': 1,
    'januar': 1,
    'feb': 2,
    'februar': 2,
    'mär': 3,
    'märz': 3,
    'mrz': 3,
    'maerz': 3,
    'apr': 4,
    'april': 4,
    'mai': 5,
    'jun': 6,
    'juni': 6,
    'jul': 7,
    'juli': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'okt': 10,
    'oktober': 10,
    'nov': 11,
    'november': 11,
    'dez': 12,
    'dezember': 12,
  };
  final match = RegExp(
    r'^\s*([a-zä]+)\.?\s+(\d{4})\s*$',
    caseSensitive: false,
  ).firstMatch(label);
  final month = match == null ? null : names[match[1]!.toLowerCase()];
  if (match == null || month == null) {
    throw const FormatException(
      'Der Kalendermonat konnte nicht sicher erkannt werden. Bitte die vollständige MyPlano-HTML-Datei mit Monatsüberschrift verwenden.',
    );
  }
  final year = int.parse(match[2]!);
  if (year < 2000 || year > 2100) {
    throw const FormatException('Ungültiges Kalenderjahr.');
  }
  return DateTime(year, month);
}

CashierDay _parseDay(Element cell, DateTime timestamp) {
  final badges = cell.querySelectorAll('.task-badge');
  final tokens = badges.isNotEmpty
      ? badges
            .map((badge) => badge.text.trim())
            .where((text) => text.isNotEmpty)
            .toList()
      : cell.text
            .trim()
            .split(RegExp(r'\s+'))
            .where((text) => text.isNotEmpty)
            .toList();
  final timePattern = RegExp(r'^(\d{1,2}):(\d{2})$');
  final times = <int>[];
  final notes = <String>[];
  for (final token in tokens) {
    final match = timePattern.firstMatch(token);
    if (match == null) {
      if (token.contains(':')) {
        throw FormatException('Ungültige Zeitangabe „$token“ im Export.');
      }
      notes.add(token);
      continue;
    }
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 24 || minute > 59 || (hour == 24 && minute != 0)) {
      throw FormatException('Ungültige Uhrzeit „$token“ im Export.');
    }
    times.add(hour * 60 + minute);
  }
  if (times.length.isOdd) {
    throw const FormatException(
      'Eine Schicht hat keine vollständige Start- und Endzeit. Der Import wurde nicht übernommen.',
    );
  }
  final shifts = <CashierShift>[];
  for (var i = 0; i < times.length; i += 2) {
    final start = times[i];
    var end = times[i + 1];
    if (start == 1440 || start == end) {
      throw const FormatException(
        'Eine Schicht enthält eine mehrdeutige Start- oder Endzeit.',
      );
    }
    if (end < start) end += 1440;
    shifts.add(CashierShift(start, end));
  }
  shifts.sort((a, b) => a.start.compareTo(b.start));
  return CashierDay(
    shifts: shifts,
    note: notes.toSet().join(' '),
    importedAt: timestamp,
  );
}
