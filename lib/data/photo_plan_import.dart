import '../models/cashier_plan.dart';

/// Editable draft. Only explicit, selected schedule cells become a patch.
/// Pause columns and text outside the recognized schedule table are never read
/// as shifts. No import may write the separately maintained `breaks` field.
class PhotoPlanImport {
  PhotoPlanImport({required this.rows, required this.warnings});
  final List<PhotoPlanRow> rows;
  final List<String> warnings;

  int get selectedCount => rows.fold(
    0,
    (sum, row) => sum + row.cells.where((cell) => cell.selected).length,
  );

  Map<String, dynamic> toPatch({
    required CashierPlan existing,
    required String fileName,
    DateTime? importedAt,
  }) {
    final timestamp = importedAt ?? DateTime.now();
    final people = <String, dynamic>{};
    final days = <String, dynamic>{};
    final months = <String>{};
    for (final row in rows) {
      final selected = row.cells.where((cell) => cell.selected);
      if (selected.isEmpty) continue;
      final name = row.name.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty || name.contains('|')) {
        throw const FormatException('Bitte einen gültigen Namen eintragen.');
      }
      final person = photoPlanPerson(existing, name);
      final id = person?.id ?? planPersonId(name);
      people[id] = person?.name ?? name;
      for (final cell in selected) {
        final day = parsePhotoPlanDay(cell.text);
        final key = '${planDateKey(cell.date)}|$id';
        if (days.containsKey(key)) {
          throw FormatException(
            '$name ist am ${planDateKey(cell.date)} mehrfach enthalten. Bitte nur einen Eintrag auswählen.',
          );
        }
        days[key] = CashierDay(
          shifts: day.shifts,
          note: day.note,
          importedAt: timestamp,
        ).toJson();
        months.add(planMonthKey(cell.date));
      }
    }
    if (days.isEmpty) {
      throw const FormatException('Bitte mindestens einen Eintrag auswählen.');
    }
    return {
      'people': people,
      'days': days,
      'imports': {
        for (final month in months)
          month: {
            'fileName': fileName,
            'source': 'photo',
            'importedAt': timestamp.toIso8601String(),
            'peopleCount': people.length,
            'warnings': warnings,
          },
      },
    };
  }
}

class PhotoPlanRow {
  PhotoPlanRow(this.name, this.cells);
  String name;
  final List<PhotoPlanCell> cells;
}

class PhotoPlanCell {
  PhotoPlanCell(this.date, this.text, {this.selected = false});
  final DateTime date;
  String text;
  bool selected;
  String? get error {
    try {
      parsePhotoPlanDay(text);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
}

CashierPerson? photoPlanPerson(CashierPlan plan, String name) => plan.people
    .where(
      (person) =>
          planPersonId(person.name) == planPersonId(name) ||
          planPersonId(person.displayName) == planPersonId(name),
    )
    .firstOrNull;

CashierDay parsePhotoPlanDay(String input) {
  final text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  const notes = {
    'ABW': 'Abwesend',
    'ABWESEND': 'Abwesend',
    'FREI': 'FREI',
    'U': 'U',
    'URLAUB': 'U',
    'AZ': 'AZ',
    'FT': 'FT',
  };
  final note = notes[text.toUpperCase()];
  if (note != null) return CashierDay(note: note);
  if (text.isEmpty || text == '-' || text == '–') {
    throw const FormatException('Leer: wird nicht übernommen.');
  }
  final pattern = RegExp(r'(\d{1,2}):([0-5]\d)\s*[-–—]\s*(\d{1,2}):([0-5]\d)');
  final matches = pattern.allMatches(text).toList();
  final rest = text.replaceAll(pattern, '').replaceAll(RegExp(r'[\s,;/]+'), '');
  if (matches.isEmpty || rest.isNotEmpty) {
    throw const FormatException(
      'Bitte Zeiten wie 06:00–14:00 oder ABW/FREI eintragen.',
    );
  }
  final shifts = <CashierShift>[];
  for (final match in matches) {
    final startHour = int.parse(match[1]!);
    final endHour = int.parse(match[3]!);
    final start = startHour * 60 + int.parse(match[2]!);
    var end = endHour * 60 + int.parse(match[4]!);
    if (startHour > 23 || endHour > 24 || end > 1440 || start == end) {
      throw const FormatException('Die Start- oder Endzeit ist ungültig.');
    }
    if (end < start) end += 1440;
    // An OCR error such as 18:00 -> 08:00 must not silently become a 22h shift.
    if (end - start > 16 * 60) {
      throw const FormatException(
        'Mehr als 16 Stunden: bitte die Uhrzeiten prüfen.',
      );
    }
    shifts.add(CashierShift(start, end));
  }
  shifts.sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < shifts.length; i++) {
    if (shifts[i].start < shifts[i - 1].end) {
      throw const FormatException('Die Schichten überschneiden sich.');
    }
  }
  return CashierDay(shifts: shifts);
}

/// Accepts the Azure v4 analyzeResult, or its complete response wrapper.
/// Does not interpret free text/handwritten notes as schedule data.
PhotoPlanImport parsePhotoPlanLayout(Map<String, dynamic> response) {
  final result = Map<String, dynamic>.from(
    response['analyzeResult'] as Map? ?? response,
  );
  final content = result['content'] as String? ?? '';
  final weekTitles =
      RegExp(r'\bKW\s*(\d{1,2})\s*/\s*(20\d{2})\b', caseSensitive: false)
          .allMatches(content)
          .map((m) => (int.parse(m[1]!), int.parse(m[2]!)))
          .toSet();
  if (weekTitles.length > 1) {
    throw const FormatException(
      'Mehrere Kalenderwochen erkannt. Bitte nur einen Wochenplan auswählen.',
    );
  }
  final title = weekTitles.firstOrNull;
  final rows = <PhotoPlanRow>[];
  var skipped = 0;
  for (final raw in result['tables'] as List? ?? []) {
    final table = Map<String, dynamic>.from(raw as Map);
    final cells = (table['cells'] as List? ?? [])
        .map((cell) => _LayoutCell(Map<String, dynamic>.from(cell as Map)))
        .toList();
    final nameHeader = cells
        .where((cell) => cell.text.toLowerCase() == 'name')
        .firstOrNull;
    if (nameHeader == null) continue;
    final columns = <int, DateTime>{};
    var lastHeader = nameHeader.row + nameHeader.rowSpan - 1;
    for (final header in cells) {
      if (header.column <= nameHeader.column || header.row > lastHeader + 1) {
        continue;
      }
      final dateMatch = RegExp(
        r'^(?:(Mo|Di|Mi|Do|Fr|Sa|So)\.?\s*[,;]?\s*)?(\d{1,2})\s*\.\s*(\d{1,2})\.?(?:\s*(20\d{2}))?$',
        caseSensitive: false,
      ).firstMatch(header.text);
      if (dateMatch == null) continue;
      // Use an explicit Arbeitszeit subheader. A dated single column is also
      // supported, but a pause column can never become a schedule column.
      final children = cells.where(
        (cell) =>
            cell.row > header.row &&
            cell.row <= header.row + 2 &&
            cell.column >= header.column &&
            cell.column < header.column + header.columnSpan,
      );
      final work = children
          .where((cell) => cell.text.toLowerCase() == 'arbeitszeit')
          .toList();
      if (work.length > 1) {
        throw const FormatException(
          'Arbeitszeit-Spalten sind nicht eindeutig erkennbar.',
        );
      }
      final _LayoutCell column;
      if (work.length == 1) {
        column = work.single;
      } else if (header.columnSpan == 1 &&
          !children.any(
            (cell) => RegExp(
              r'^(p|pause)$',
              caseSensitive: false,
            ).hasMatch(cell.text),
          )) {
        column = header;
      } else {
        throw const FormatException(
          'Die Arbeitszeit-Spalten konnten nicht sicher von den Pausen getrennt werden.',
        );
      }
      final date = _headerDate(dateMatch, title);
      if (columns.containsValue(date) || columns.containsKey(column.column)) {
        throw const FormatException(
          'Eine Tagesüberschrift wurde mehrfach erkannt.',
        );
      }
      columns[column.column] = date;
      final bottom = column.row + column.rowSpan - 1;
      if (bottom > lastHeader) lastHeader = bottom;
    }
    if (columns.isEmpty) continue;
    final nameCells = cells.where(
      (cell) => cell.column == nameHeader.column && cell.row > lastHeader,
    );
    for (final name in nameCells) {
      if (name.text.isEmpty || name.rowSpan != 1 || name.columnSpan != 1) {
        skipped++;
        continue;
      }
      final entries = <PhotoPlanCell>[];
      for (final column in columns.entries) {
        final matches = cells
            .where((cell) => cell.row == name.row && cell.column == column.key)
            .toList();
        final cell = matches.length == 1 ? matches.single : null;
        // Merged data cells cannot be safely assigned to just one day/person.
        final entry = PhotoPlanCell(
          column.value,
          cell == null
              ? ''
              : cell.rowSpan != 1 || cell.columnSpan != 1
              ? 'Unklare Tabellenzelle'
              : cell.text,
        );
        entry.selected = entry.error == null;
        entries.add(entry);
      }
      entries.sort((a, b) => a.date.compareTo(b.date));
      rows.add(PhotoPlanRow(name.text, entries));
    }
  }
  if (rows.isEmpty) {
    throw const FormatException(
      'Keine eindeutige Wochenplantabelle erkannt. Bitte den vollständigen Plan mit Namen, Datum und Jahresüberschrift fotografieren.',
    );
  }
  return PhotoPlanImport(
    rows: rows,
    warnings: [
      if (skipped > 0) '$skipped uneindeutige Namenszeilen wurden ausgelassen.',
      if (RegExp(r'nicht\s+genehmigt', caseSensitive: false).hasMatch(content))
        'Auf dem Foto steht „Nicht genehmigt“.',
    ],
  );
}

DateTime _headerDate(RegExpMatch match, (int, int)? title) {
  final day = int.parse(match[2]!);
  final month = int.parse(match[3]!);
  final explicitYear = match[4] == null ? null : int.parse(match[4]!);
  if (explicitYear == null && title == null) {
    throw const FormatException(
      'Das Jahr fehlt. Bitte die Überschrift „KW … / Jahr“ mit aufnehmen.',
    );
  }
  final years = explicitYear != null
      ? [explicitYear]
      : [title!.$2 - 1, title.$2, title.$2 + 1];
  final dates = years.map((year) => DateTime(year, month, day)).where((date) {
    if (date.month != month || date.day != day) return false;
    if (title == null) return true;
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final first = DateTime(thursday.year, 1, 4);
    final firstThursday = first.add(
      Duration(days: DateTime.thursday - first.weekday),
    );
    final week =
        ((thursday.toUtc().difference(firstThursday.toUtc()).inHours / 24)
                .round() ~/
            7) +
        1;
    return thursday.year == title.$2 && week == title.$1;
  }).toList();
  if (dates.length != 1) {
    throw const FormatException(
      'Datum und Kalenderwoche passen nicht zusammen. Bitte die Tagesüberschriften prüfen.',
    );
  }
  final date = dates.single;
  const weekdays = ['mo', 'di', 'mi', 'do', 'fr', 'sa', 'so'];
  if (match[1] != null &&
      weekdays[date.weekday - 1] != match[1]!.toLowerCase()) {
    throw const FormatException(
      'Datum und Wochentag widersprechen sich. Bitte das Foto prüfen.',
    );
  }
  return date;
}

class _LayoutCell {
  _LayoutCell(Map<String, dynamic> data)
    : row = data['rowIndex'] as int,
      column = data['columnIndex'] as int,
      rowSpan = data['rowSpan'] as int? ?? 1,
      columnSpan = data['columnSpan'] as int? ?? 1,
      text = (data['content'] as String? ?? '').trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
  final String text;
}
