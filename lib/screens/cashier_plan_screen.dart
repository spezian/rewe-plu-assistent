import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/app_constants.dart';
import '../data/myplano_import.dart';
import '../models/cashier_plan.dart';
import '../widgets/cashier_break_dialog.dart';

const _cashierColor = Color(0xFF087F73);
const _managerColor = Color(0xFF6550A3);
const _muted = Color(0xFF66716F);
const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];
String _dateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day}. ${_months[date.month - 1]} ${date.year}';
Color _roleColor(CashierRole role) =>
    role == CashierRole.manager ? _managerColor : _cashierColor;

class CashierPlanScreen extends StatefulWidget {
  const CashierPlanScreen({super.key, this.isActive = true, this.now});
  final bool isActive;
  final DateTime Function()? now;

  @override
  State<CashierPlanScreen> createState() => _CashierPlanScreenState();
}

class _CashierPlanScreenState extends State<CashierPlanScreen> {
  late DateTime _date;
  Timer? _timer;
  CashierRole? _role;
  bool _nowOnly = false;
  bool _busy = false;
  bool _followToday = true;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _date = DateUtils.dateOnly(_now);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.isActive) {
        setState(() {
          if (_followToday) _date = DateUtils.dateOnly(_now);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectDate(DateTime date) => setState(() {
    _date = DateUtils.dateOnly(date);
    _followToday = DateUtils.isSameDay(_date, _now);
    _nowOnly = false;
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final plan = controller.cashierPlan;
        final now = _now;
        final today = DateUtils.isSameDay(_date, now);
        final minute = now.hour * 60 + now.minute;
        final people = cashierDayPeople(plan, _date, role: _role);
        final freeDay = plan.freeDayReason(_date);
        final working = people.where((p) => p.day.shifts.isNotEmpty).toList()
          ..sort((a, b) {
            final compare = a.day.shifts.first.start.compareTo(
              b.day.shifts.first.start,
            );
            return compare == 0
                ? a.person.name.compareTo(b.person.name)
                : compare;
          });
        final visible = working
            .where((p) => !_nowOnly || p.day.isAvailableAt(minute))
            .toList();
        final absent = people.where((p) => p.day.isAbsent).toList();
        final unknown = people
            .where((p) => p.day.shifts.isEmpty && !p.day.isAbsent)
            .toList();
        final active = working.where((p) => p.day.isAvailableAt(minute)).length;
        final onBreak = working.where((p) => p.day.isOnBreak(minute)).length;
        final start =
            working.fold<int>(
              360,
              (v, p) => math.min(v, p.day.shifts.first.start),
            ) ~/
            240 *
            240;
        final end = math.min(
          1440,
          ((working.fold<int>(
                        1320,
                        (v, p) => math.max(v, p.day.shifts.last.end),
                      ) +
                      239) ~/
                  240) *
              240,
        );
        final metadata = plan.importFor(_date);
        return Material(
          color: const Color(0xFFF5F7F6),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dienstübersicht',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (controller.canEdit) ...[
                        IconButton(
                          tooltip: 'Team & Rollen',
                          onPressed: _busy
                              ? null
                              : () => _editRoles(controller),
                          icon: const Icon(Icons.manage_accounts_outlined),
                        ),
                        IconButton(
                          tooltip: 'MyPlano-HTML importieren',
                          onPressed: _busy ? null : () => _import(controller),
                          icon: const Icon(Icons.file_upload_outlined),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _dateNavigation(),
                  if (freeDay != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _message(
                        Icons.event_available_outlined,
                        freeDay == 'FT'
                            ? 'Feiertag · alle frei'
                            : 'Sonntag · alle frei',
                        'Heute ist für das gesamte Team ein freier Tag.',
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (plan.people.isEmpty)
                    _emptyPlan(controller)
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final option in <CashierRole?>[
                          null,
                          CashierRole.cashier,
                          CashierRole.manager,
                        ])
                          ChoiceChip(
                            label: Text(
                              option == null
                                  ? 'Alle'
                                  : option == CashierRole.cashier
                                  ? 'Kasse'
                                  : 'Marktleitung',
                            ),
                            selected: _role == option,
                            onSelected: (_) => setState(() => _role = option),
                            avatar: option == null
                                ? null
                                : Icon(
                                    option == CashierRole.cashier
                                        ? Icons.point_of_sale
                                        : Icons.badge_outlined,
                                    size: 17,
                                  ),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (plan.people.every((p) => p.role == CashierRole.hidden))
                      _message(
                        Icons.people_outline,
                        'Team auswählen',
                        controller.canEdit
                            ? 'Ordne unter „Team & Rollen“ Kassierer und Marktleiter zu. Alle anderen bleiben ausgeblendet.'
                            : 'Es wurden noch keine Kassierer oder Marktleiter zugeordnet.',
                        action: controller.canEdit
                            ? TextButton(
                                onPressed: () => _editRoles(controller),
                                child: const Text('Team & Rollen'),
                              )
                            : null,
                      )
                    else ...[
                      if (freeDay == null)
                        _summary(
                          working.length,
                          today ? active : null,
                          today ? onBreak : 0,
                        ),
                      if (today && working.isNotEmpty)
                        _nextChange(working, minute),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _nowOnly ? 'Jetzt im Dienst' : 'Tagesschichten',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (today)
                            FilterChip(
                              label: const Text('Jetzt da'),
                              selected: _nowOnly,
                              onSelected: (v) => setState(() => _nowOnly = v),
                            )
                          else
                            Text(
                              '${visible.length} Personen',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (visible.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _TimeAxis(start: start, end: end),
                        ),
                        const SizedBox(height: 6),
                        for (final person in visible)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ShiftCard(
                              entry: person,
                              start: start,
                              end: end,
                              minute: today ? minute : null,
                              breakPlan: plan.breakFor(person.person.id, _date),
                              showBreakHints: controller.canEdit,
                              onEditBreak:
                                  controller.canEdit &&
                                      (plan
                                                  .breakFor(
                                                    person.person.id,
                                                    _date,
                                                  )
                                                  .duration >
                                              0 ||
                                          plan.breakStart(
                                                person.person.id,
                                                _date,
                                              ) !=
                                              null)
                                  ? () => showDialog<void>(
                                      context: context,
                                      builder: (_) => CashierBreakDialog(
                                        controller: controller,
                                        person: person.person,
                                        date: _date,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 12),
                          child: Text(
                            'Schichtzeiten laut MyPlano. Orange markiert die eingetragenen Pausen.',
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ),
                      ] else if (freeDay == null)
                        _message(
                          Icons.event_available_outlined,
                          _nowOnly
                              ? 'Gerade niemand eingeplant'
                              : 'Keine Schichtzeiten vorhanden',
                          unknown.isNotEmpty
                              ? 'Für ${unknown.length} Personen fehlen eindeutige Zeiten. Siehe „Ohne Zeitangabe“.'
                              : 'Für diese Auswahl sind keine Schichten hinterlegt.',
                        ),
                      if (absent.isNotEmpty)
                        _foldedPeople(
                          'Abwesend / frei',
                          absent,
                          Icons.person_off_outlined,
                        ),
                      if (unknown.isNotEmpty)
                        _foldedPeople(
                          'Ohne Zeitangabe',
                          unknown,
                          Icons.help_outline,
                        ),
                    ],
                    const SizedBox(height: 16),
                    if (metadata == null)
                      _message(
                        Icons.info_outline,
                        'Kein Import für diesen Monat',
                        'Wähle einen importierten Monat oder lade eine weitere MyPlano-HTML-Datei.',
                      )
                    else
                      _sourceInfo(metadata),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dateNavigation() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE1E7E4)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Vorheriger Tag',
              onPressed: () =>
                  _selectDate(DateTime(_date.year, _date.month, _date.day - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton(
                onPressed: () async {
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100, 12, 31),
                    helpText: 'Tag auswählen',
                    cancelText: 'Abbrechen',
                    confirmText: 'Auswählen',
                  );
                  if (chosen != null && mounted) _selectDate(chosen);
                },
                child: Text(
                  _dateLabel(_date),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF253B34),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Nächster Tag',
              onPressed: () =>
                  _selectDate(DateTime(_date.year, _date.month, _date.day + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (!DateUtils.isSameDay(_date, _now))
          TextButton(
            onPressed: () => _selectDate(_now),
            child: const Text('Zurück zu heute'),
          ),
      ],
    ),
  );

  Widget _summary(int count, int? active, int onBreak) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF233D34),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_2_outlined, color: Color(0xFFBCE7CF), size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active == null
                    ? '$count Personen eingeplant'
                    : '$active laut Plan verfügbar',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                active == null
                    ? 'Für den ausgewählten Tag'
                    : '$count Personen über den Tag verteilt${onBreak > 0 ? ' · $onBreak in Pause' : ''}',
                style: const TextStyle(color: Color(0xFFCCDBD4), fontSize: 12),
              ),
            ],
          ),
        ),
        if (active != null)
          Text(
            planTime(_now.hour * 60 + _now.minute),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
  );

  Widget _nextChange(List<CashierDayPerson> people, int minute) {
    final events = <({int time, String name, String action})>[];
    for (final p in people) {
      for (final shift in p.day.shifts) {
        if (shift.start > minute && shift.start < 1440) {
          events.add((
            time: shift.start,
            name: p.person.displayName,
            action: 'Kommt',
          ));
        }
        if (shift.end > minute && shift.end < 1440) {
          events.add((
            time: shift.end,
            name: p.person.displayName,
            action: 'Geht',
          ));
        }
      }
      for (final pause in p.day.breaks) {
        if (pause.start > minute && pause.start < 1440) {
          events.add((
            time: pause.start,
            name: p.person.displayName,
            action: 'Pause',
          ));
        }
        if (pause.end > minute && pause.end < 1440) {
          events.add((
            time: pause.end,
            name: p.person.displayName,
            action: 'Zurück aus Pause',
          ));
        }
      }
    }
    if (events.isEmpty) return const SizedBox.shrink();
    events.sort((a, b) => a.time.compareTo(b.time));
    final next = events.where((e) => e.time == events.first.time);
    final groups = <String, String>{
      for (final action in ['Kommt', 'Geht', 'Pause', 'Zurück aus Pause'])
        action: next
            .where((e) => e.action == action)
            .map((e) => e.name)
            .toSet()
            .join(', '),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1ED),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nächster Wechsel · ${planTime(events.first.time)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF233D34),
              ),
            ),
            for (final group in groups.entries.where((e) => e.value.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '${group.key}: ${group.value}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _foldedPeople(
    String title,
    List<CashierDayPerson> people,
    IconData icon,
  ) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(top: 8),
    child: ExpansionTile(
      key: PageStorageKey('$title:${planDateKey(_date)}:${_role?.name}'),
      leading: Icon(icon, size: 20, color: _muted),
      title: Text(
        '$title (${people.length})',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: [
        for (final p in people)
          ListTile(
            dense: true,
            title: Text(p.person.displayName),
            subtitle: Text(p.person.role.label),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 115),
              child: Text(
                p.day.status,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _sourceInfo(Map<String, dynamic> metadata) {
    final imported = DateTime.tryParse(metadata['importedAt'] as String? ?? '')
        ?.toLocal();
    // Older imports stored the former AZ warning alongside their source data.
    final warnings = (metadata['warnings'] as List? ?? [])
        .cast<String>()
        .where((warning) => !warning.contains('(z. B. AZ)'))
        .toList();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(
        warnings.isEmpty ? Icons.task_alt : Icons.info_outline,
        color: _muted,
        size: 20,
      ),
      title: Text(
        warnings.isEmpty
            ? 'MyPlano · Importdetails'
            : 'MyPlano · Export mit Hinweisen',
        style: const TextStyle(fontSize: 13, color: _muted),
      ),
      subtitle: imported == null
          ? null
          : Text(
              'Importiert am ${imported.day}.${imported.month}.${imported.year} um ${planTime(imported.hour * 60 + imported.minute)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            metadata['fileName'] as String? ?? 'HTML-Import',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              warning,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
      ],
    );
  }

  Widget _emptyPlan(AppController controller) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: _message(
      Icons.calendar_month_outlined,
      'Der Kassenplan beginnt hier',
      controller.canEdit
          ? 'Importiere den Gruppenkalender aus MyPlano als HTML-Datei. Wähle danach aus, wer an der Kasse und in der Marktleitung arbeitet.'
          : 'Für diesen Markt wurde noch kein Kassenplan importiert. Der Import ist im Bearbeitungsmodus möglich.',
      action: controller.canEdit
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _import(controller),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('MyPlano-HTML importieren'),
              ),
            )
          : null,
    ),
  );

  Widget _message(
    IconData icon,
    String title,
    String description, {
    Widget? action,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _cashierColor, size: 28),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(description, style: const TextStyle(color: _muted, height: 1.45)),
        ?action,
      ],
    ),
  );

  Future<void> _editRoles(AppController controller) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => CashierTeamScreen(controller: controller),
        ),
      );

  Future<void> _import(AppController controller) async {
    final marketId = controller.repository.marketSession?.marketId;
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['html', 'htm'],
      );
      if (file == null) return;
      if (await file.length() > 15 * 1024 * 1024) {
        throw const FormatException('Die Datei ist zu groß (maximal 15 MB).');
      }
      final bytes = await file.readAsBytes();
      final source = utf8.decode(
        bytes,
      ); // Reject broken encoding instead of changing names silently.
      final imported = await compute(_parseImport, (
        source: source,
        name: file.name,
      ));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kassenplan importieren'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_months[imported.month.month - 1]} ${imported.month.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${imported.peopleCount} Personen · ${imported.shiftCount} Schichten',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vorhandene Tagesfelder dieser Personen werden aktualisiert. Rollen und Daten außerhalb des Exports bleiben erhalten.',
                ),
                for (final warning in imported.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      warning,
                      style: const TextStyle(color: Color(0xFF865500)),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Neue Personen bleiben ausgeblendet, bis du ihnen eine Rolle zuordnest.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importieren'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (controller.repository.marketSession?.marketId != marketId) {
        throw StateError(
          'Der Markt wurde gewechselt. Bitte den Import erneut starten.',
        );
      }
      await controller.saveCashierPlanPatch(imported.patch);
      if (!mounted) return;
      final now = _now;
      _selectDate(
        planMonthKey(now) == planMonthKey(imported.month)
            ? now
            : imported.month,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${imported.peopleCount} Personen importiert. Rollen können unter „Team & Rollen“ eingestellt werden.',
          ),
        ),
      );
      if (controller.cashierPlan.people.every(
        (p) => p.role == CashierRole.hidden,
      )) {
        await _editRoles(controller);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Import fehlgeschlagen: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

MyPlanoImport _parseImport(({String source, String name}) input) =>
    parseMyPlanoHtml(input.source, fileName: input.name);

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.start, required this.end});
  final int start;
  final int end;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (var minute = start; minute <= end; minute += 240)
        Text(
          minute == 1440 ? '24' : '${minute ~/ 60}'.padLeft(2, '0'),
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
    ],
  );
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.entry,
    required this.start,
    required this.end,
    this.minute,
    required this.breakPlan,
    required this.showBreakHints,
    this.onEditBreak,
  });
  final CashierDayPerson entry;
  final int start;
  final int end;
  final int? minute;
  final CashierBreakPlan breakPlan;
  final bool showBreakHints;
  final VoidCallback? onEditBreak;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(entry.person.role);
    final active = minute != null && entry.day.isAvailableAt(minute!);
    final onBreak = minute != null && entry.day.isOnBreak(minute!);
    final finished =
        minute != null && entry.day.shifts.every((s) => s.end <= minute!);
    final status = minute == null
        ? entry.person.role.label
        : onBreak
        ? 'In Pause bis ${planTime(entry.day.breaks.firstWhere((s) => s.contains(minute!)).end)}'
        : active
        ? 'Jetzt da'
        : finished
        ? 'Feierabend'
        : 'Kommt um ${planTime(entry.day.shifts.firstWhere((s) => s.start > minute!, orElse: () => entry.day.shifts.last).start)}';
    return Semantics(
      label:
          '${entry.person.displayName}, ${entry.person.role.label}, ${entry.day.shifts.map((s) => s.label).join(', ')}, $status',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: finished ? const Color(0xFFF0F2F1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? color.withValues(alpha: .5)
                : const Color(0xFFE2E8E5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    entry.person.role == CashierRole.manager
                        ? Icons.badge_outlined
                        : Icons.point_of_sale,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.person.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.day.shifts.map((s) => s.label).join(' · '),
                        style: TextStyle(
                          fontSize: 13,
                          color: finished ? _muted : const Color(0xFF253B34),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEditBreak != null)
                  IconButton(
                    tooltip: 'Pause für ${entry.person.displayName}',
                    icon: const Icon(Icons.free_breakfast_outlined, size: 20),
                    onPressed: onEditBreak,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F3F1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    for (var tick = start; tick <= end; tick += 60)
                      Positioned(
                        left:
                            (tick - start) /
                            (end - start) *
                            (constraints.maxWidth - 1),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: const Color(0xFFDDE5E0),
                        ),
                      ),
                    for (final shift in entry.day.shifts)
                      Positioned(
                        left:
                            (shift.start.clamp(start, end) - start) /
                            (end - start) *
                            constraints.maxWidth,
                        width:
                            (shift.end.clamp(start, end) -
                                shift.start.clamp(start, end)) /
                            (end - start) *
                            constraints.maxWidth,
                        top: 3,
                        bottom: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: finished
                                ? color.withValues(alpha: .4)
                                : color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    for (final pause in entry.day.breaks)
                      Positioned(
                        left:
                            (pause.start.clamp(start, end) - start) /
                            (end - start) *
                            constraints.maxWidth,
                        width:
                            (pause.end.clamp(start, end) -
                                pause.start.clamp(start, end)) /
                            (end - start) *
                            constraints.maxWidth,
                        top: 1,
                        bottom: 1,
                        child: Tooltip(
                          message: 'Pause ${pause.label}',
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8A13B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    if (minute != null && minute! >= start && minute! <= end)
                      Positioned(
                        left:
                            (minute! - start) /
                            (end - start) *
                            constraints.maxWidth,
                        top: -3,
                        bottom: -3,
                        child: Container(width: 2, color: reweDarkRed),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 3,
              children: [
                Text(
                  entry.person.role.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (minute != null)
                  Text(
                    '· $status',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                      color: active ? color : _muted,
                    ),
                  ),
              ],
            ),
            if (entry.day.breaks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  entry.day.breaks
                      .map((s) => 'Pause ${s.label} · ${s.end - s.start} Min.')
                      .join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF825013),
                  ),
                ),
              )
            else if (showBreakHints &&
                entry.day.breakIssue == null &&
                breakPlan.duration > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Pause noch offen · ${breakPlan.duration} Min.',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
            if (showBreakHints && entry.day.breakIssue != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Pause prüfen: ${entry.day.breakIssue}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CashierTeamScreen extends StatefulWidget {
  const CashierTeamScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<CashierTeamScreen> createState() => _CashierTeamScreenState();
}

class _CashierTeamScreenState extends State<CashierTeamScreen> {
  late final List<CashierPerson> _people = widget.controller.cashierPlan.people;
  late final String? _marketId;
  final Map<String, String> _changes = {};
  final Map<String, bool> _ageChanges = {};
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _marketId = widget.controller.repository.marketSession?.marketId;
  }

  @override
  Widget build(BuildContext context) {
    final people = _people
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final selected = _people
        .where(
          (p) =>
              CashierRole.fromValue(_changes[p.id] ?? p.role.name) !=
              CashierRole.hidden,
        )
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Team & Rollen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nur Kassierer und Marktleiter erscheinen im Kassenplan. Die Zuordnung bleibt beim nächsten Import erhalten.',
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Person suchen',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$selected ausgewählt · ${_people.length} importiert',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: people.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final person = people[index];
                final role = CashierRole.fromValue(
                  _changes[person.id] ?? person.role.name,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      DropdownButton<CashierRole>(
                        value: role,
                        isExpanded: true,
                        items: [
                          for (final option in CashierRole.values)
                            DropdownMenuItem(
                              value: option,
                              child: Text(option.label),
                            ),
                        ],
                        onChanged: _saving || !widget.controller.canEdit
                            ? null
                            : (value) => setState(() {
                                if (value == person.role) {
                                  _changes.remove(person.id);
                                } else {
                                  _changes[person.id] = value!.name;
                                }
                              }),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Unter 18 Jahre'),
                        subtitle: const Text(
                          'Gesetzliche Pausenregel für Jugendliche',
                        ),
                        value: _ageChanges[person.id] ?? person.under18,
                        onChanged: _saving || !widget.controller.canEdit
                            ? null
                            : (value) => setState(() {
                                if (value == person.under18) {
                                  _ageChanges.remove(person.id);
                                } else {
                                  _ageChanges[person.id] = value;
                                }
                              }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || !widget.controller.canEdit
                      ? null
                      : _save,
                  icon: const Icon(Icons.check),
                  label: Text(
                    _saving ? 'Wird gespeichert …' : 'Zuordnung speichern',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (widget.controller.repository.marketSession?.marketId != _marketId) {
        throw StateError('Der Markt wurde gewechselt.');
      }
      if (_changes.isNotEmpty || _ageChanges.isNotEmpty) {
        await widget.controller.saveCashierPlanPatch({
          'roles': _changes,
          'under18': _ageChanges,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zuordnung nicht gespeichert: $error')),
        );
      }
    }
  }
}
