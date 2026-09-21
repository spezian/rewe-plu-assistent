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
  });
  final String id;
  final String name;
  final CashierRole role;

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
  const CashierDay({this.shifts = const [], this.note = '', this.importedAt});
  final List<CashierShift> shifts;
  final String note;
  final DateTime? importedAt;
  bool get isAbsent =>
      shifts.isEmpty &&
      const ['', 'FREI', 'U', 'Abwesend', 'AZ'].contains(note);
  String get status => switch (note) {
    'FREI' => 'Frei',
    'U' => 'Urlaub',
    'Abwesend' => 'Abwesend',
    'AZ' => 'AZ',
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
  static const fields = ['people', 'roles', 'days', 'imports'];
  Map<String, dynamic> field(String name) =>
      Map<String, dynamic>.from(data[name] as Map? ?? {});

  List<CashierPerson> get people {
    final roles = field('roles');
    return field('people').entries
        .map(
          (entry) => CashierPerson(
            id: entry.key,
            name: entry.value as String,
            role: CashierRole.fromValue(roles[entry.key]),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  CashierDay day(String personId, DateTime date) {
    final value = (data['days'] as Map?)?['${planDateKey(date)}|$personId'];
    return value == null
        ? const CashierDay()
        : CashierDay.fromJson(Map<String, dynamic>.from(value as Map));
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
        final overnight = plan
            .day(p.id, previous)
            .shifts
            .where((s) => s.end > 1440)
            .map((s) => CashierShift(0, s.end - 1440));
        return CashierDayPerson(
          p,
          CashierDay(
            shifts: [...overnight, ...today.shifts]
              ..sort((a, b) => a.start.compareTo(b.start)),
            note: today.note,
            importedAt: today.importedAt,
          ),
        );
      })
      .toList();
}
