enum CashierRole {
  hidden('Ausblenden'),
  cashier('Kassierer'),
  manager('Marktleiter');

  const CashierRole(this.label);
  final String label;

  static CashierRole fromValue(Object? value) =>
      values.where((role) => role.name == value).firstOrNull ?? hidden;
}

String planDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
String planMonthKey(DateTime date) => planDateKey(date).substring(0, 7);
String planPersonId(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
String planTime(int minutes) =>
    '${(minutes ~/ 60 % 24).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

class CashierPerson {
  const CashierPerson({
    required this.id,
    required this.name,
    required this.role,
    this.under18 = false,
  });
  final String id;
  final String name;
  final CashierRole role;
  final bool under18;

  String get displayName {
    final parts = name.split(',');
    return parts.length == 2 ? '${parts[1].trim()} ${parts[0].trim()}' : name;
  }
}

class CashierShift {
  const CashierShift(this.start, this.end);
  final int start;
  // Minutes from midnight; an overnight shift can end after minute 1440.
  final int end;
  String get label =>
      '${planTime(start)}–${planTime(end)}${end >= 1440 ? ' (+1)' : ''}';
  bool contains(int minute) => start <= minute && minute < end;
  Map<String, dynamic> toJson() => {'start': start, 'end': end};
  factory CashierShift.fromJson(Map<String, dynamic> value) =>
      CashierShift(value['start'] as int, value['end'] as int);
}

class CashierDay {
  const CashierDay({
    this.shifts = const [],
    this.note = '',
    this.importedAt,
    this.breaks = const [],
    this.breakIssue,
  });
  final List<CashierShift> shifts;
  final String note;
  final DateTime? importedAt;
  // Derived from the separately stored manual start; never part of an import.
  final List<CashierShift> breaks;
  final String? breakIssue;
  bool isOnBreak(int minute) => breaks.any((pause) => pause.contains(minute));
  bool isAvailableAt(int minute) =>
      shifts.any((shift) => shift.contains(minute)) && !isOnBreak(minute);
  bool get isAbsent =>
      shifts.isEmpty &&
      const ['', 'FREI', 'U', 'Abwesend', 'AZ', 'FT', 'SONNTAG'].contains(note);
  String get status => switch (note) {
    'FREI' => 'Frei',
    'U' => 'Urlaub',
    'Abwesend' => 'Abwesend',
    'AZ' => 'AZ',
    'FT' => 'Feiertag',
    'SONNTAG' => 'Sonntag · frei',
    '' => 'Keine Daten',
    _ => '$note · ohne Zeitangabe',
  };
  Map<String, dynamic> toJson() => {
    'shifts': shifts.map((shift) => shift.toJson()).toList(),
    'note': note,
    'importedAt': importedAt?.toIso8601String(),
  };
  factory CashierDay.fromJson(Map<String, dynamic> value) => CashierDay(
    shifts: (value['shifts'] as List? ?? [])
        .map((v) => CashierShift.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    note: value['note'] as String? ?? '',
    importedAt: DateTime.tryParse(value['importedAt'] as String? ?? ''),
  );
}

/// Patches merge individual people, dates and roles, so a partial HTML export
/// never deletes people outside the captured viewport or an earlier month.
class CashierPlan {
  const CashierPlan([this.data = const {}]);
  final Map<String, dynamic> data;
  static const fields = [
    'people',
    'roles',
    'days',
    'imports',
    'breaks',
    'under18',
  ];
  Map<String, dynamic> field(String name) =>
      Map<String, dynamic>.from(data[name] as Map? ?? {});

  List<CashierPerson> get people {
    final roles = field('roles');
    final minors = field('under18');
    return field('people').entries
        .map(
          (entry) => CashierPerson(
            id: entry.key,
            name: entry.value as String,
            role: CashierRole.fromValue(roles[entry.key]),
            under18: minors[entry.key] == true,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  CashierDay day(String personId, DateTime date) {
    final raw = scheduledDay(personId, date);
    final pause = breakFor(personId, date);
    return CashierDay(
      shifts: raw.shifts,
      note: raw.note,
      importedAt: raw.importedAt,
      breaks: [?pause.interval],
      breakIssue: pause.error,
    );
  }

  /// A single FT anywhere in the imported day closes the whole market,
  /// including when the source person is hidden from the cashier overview.
  String? freeDayReason(DateTime date) {
    final prefix = '${planDateKey(date)}|';
    for (final entry in (data['days'] as Map? ?? {}).entries) {
      if ((entry.key as String).startsWith(prefix) &&
          RegExp(r'\bFT\b')
              .hasMatch((entry.value as Map)['note'] as String? ?? '')) {
        return 'FT';
      }
    }
    return date.weekday == DateTime.sunday ? 'SONNTAG' : null;
  }

  CashierDay scheduledDay(String personId, DateTime date) {
    final free = freeDayReason(date);
    if (free != null) return CashierDay(note: free);
    final value = (data['days'] as Map?)?['${planDateKey(date)}|$personId'];
    return value == null
        ? const CashierDay()
        : CashierDay.fromJson(Map<String, dynamic>.from(value as Map));
  }

  int? breakStart(String personId, DateTime date) =>
      (data['breaks'] as Map?)?['${planDateKey(date)}|$personId'] as int?;

  CashierBreakPlan breakFor(String personId, DateTime date) {
    final shifts = scheduledDay(personId, date).shifts;
    if (shifts.isEmpty) return const CashierBreakPlan(duration: 0);
    return calculateCashierBreak(
      shifts,
      under18: (data['under18'] as Map?)?[personId] == true,
      start: breakStart(personId, date),
    );
  }

  Map<String, dynamic>? importFor(DateTime date) {
    final value = (data['imports'] as Map?)?[planMonthKey(date)];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  CashierPlan merge(Map<String, dynamic> patch) =>
      CashierPlan(mergeData(data, patch));
  static Map<String, dynamic> mergeData(
    Map<String, dynamic> base,
    Map<String, dynamic> patch,
  ) => {
    for (final field in fields)
      field: {...?base[field] as Map?, ...?patch[field] as Map?},
  };
}

class CashierDayPerson {
  const CashierDayPerson(this.person, this.day);
  final CashierPerson person;
  final CashierDay day;
}

/// Includes the tail of yesterday's overnight shift in today's overview.
List<CashierDayPerson> cashierDayPeople(
  CashierPlan plan,
  DateTime date, {
  CashierRole? role,
}) {
  final previous = DateTime(date.year, date.month, date.day - 1);
  return plan.people
      .where(
        (p) => p.role != CashierRole.hidden && (role == null || p.role == role),
      )
      .map((p) {
        final today = plan.day(p.id, date);
        if (plan.freeDayReason(date) != null) return CashierDayPerson(p, today);
        final yesterday = plan.day(p.id, previous);
        final overnight = yesterday.shifts
            .where((s) => s.end > 1440)
            .map((s) => CashierShift(0, s.end - 1440));
        return CashierDayPerson(
          p,
          CashierDay(
            shifts: [...overnight, ...today.shifts]
              ..sort((a, b) => a.start.compareTo(b.start)),
            note: today.note,
            importedAt: today.importedAt,
            breaks: [
              ...yesterday.breaks
                  .where((s) => s.end > 1440)
                  .map(
                    (s) => CashierShift(
                      (s.start - 1440).clamp(0, 1440),
                      s.end - 1440,
                    ),
                  ),
              ...today.breaks,
            ],
            breakIssue:
                today.breakIssue ??
                (overnight.isNotEmpty ? yesterday.breakIssue : null),
          ),
        );
      })
      .toList();
}

class CashierBreakPlan {
  const CashierBreakPlan({required this.duration, this.start, this.error});
  final int duration;
  final int? start;
  final String? error;
  CashierShift? get interval => start == null || duration == 0 || error != null
      ? null
      : CashierShift(start!, start! + duration);
}

/// Statutory standard blocks. The supplied MyPlano intervals INCLUDE breaks.
/// Pick the smallest standard block meeting the rule for the resulting NET
/// working time. E.g. a 9h30 span minus 30min is exactly 9h of work.
/// Sources: ArbZG §§ 2, 4; JArbSchG § 11 (see README).
CashierBreakPlan calculateCashierBreak(
  List<CashierShift> shifts, {
  bool under18 = false,
  int? start,
}) {
  final sorted = [...shifts]..sort((a, b) => a.start.compareTo(b.start));
  final spans = <CashierShift>[];
  for (final shift in sorted) {
    if (spans.isNotEmpty && shift.start <= spans.last.end) {
      final last = spans.removeLast();
      spans.add(
        CashierShift(last.start, shift.end > last.end ? shift.end : last.end),
      );
    } else {
      spans.add(shift);
    }
  }
  final total = spans.fold<int>(
    0,
    (sum, shift) => sum + shift.end - shift.start,
  );
  int requiredFor(int work) => under18
      ? (work > 360
            ? 60
            : work > 270
            ? 30
            : 0)
      : (work > 540
            ? 45
            : work > 360
            ? 30
            : 0);
  final duration = (under18 ? [0, 30, 60] : [0, 30, 45]).firstWhere(
    (candidate) => candidate >= requiredFor(total - candidate),
  );
  CashierBreakPlan result([String? error]) =>
      CashierBreakPlan(duration: duration, start: start, error: error);
  if (start == null) return result();
  if (duration == 0) {
    return result('Für diese Schicht ist keine Pflichtpause vorgesehen.');
  }
  final end = start + duration;
  if (!spans.any((shift) => start > shift.start && end < shift.end)) {
    return result(
      'Die gesamte Pause muss innerhalb einer Schicht liegen und die Arbeit unterbrechen.',
    );
  }
  if (under18 &&
      (start < spans.first.start + 60 || end > spans.last.end - 60)) {
    return result(
      'Unter 18: Die Pause muss mindestens eine Stunde nach Schichtbeginn beginnen und eine Stunde vor Schichtende enden.',
    );
  }
  final work = <CashierShift>[];
  for (final shift in spans) {
    if (start > shift.start && end < shift.end) {
      work.add(CashierShift(shift.start, start));
      work.add(CashierShift(end, shift.end));
    } else {
      work.add(shift);
    }
  }
  final limit = under18 ? 270 : 360;
  int? uninterruptedStart;
  int? previousEnd;
  for (final part in work) {
    if (previousEnd == null || part.start - previousEnd >= 15) {
      uninterruptedStart = part.start;
    }
    if (part.end - uninterruptedStart! > limit) {
      return result(
        'Maximal ${under18 ? '4½' : '6'} Stunden Arbeit am Stück. Bitte einen anderen Pausenbeginn wählen.',
      );
    }
    previousEnd = part.end;
  }
  return result();
}
