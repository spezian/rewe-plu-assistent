import 'package:material_ui/material_ui.dart';

import '../app_controller.dart';
import '../models/cashier_plan.dart';

class CashierBreakDialog extends StatefulWidget {
  const CashierBreakDialog({
    super.key,
    required this.controller,
    required this.person,
    required this.date,
  });
  final AppController controller;
  final CashierPerson person;
  final DateTime date;

  @override
  State<CashierBreakDialog> createState() => _CashierBreakDialogState();
}

class _CashierBreakDialogState extends State<CashierBreakDialog> {
  final _input = TextEditingController();
  late final String? _marketId;
  bool _nextDay = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _marketId = widget.controller.repository.marketSession?.marketId;
    final start = widget.controller.cashierPlan.breakStart(
      widget.person.id,
      widget.date,
    );
    if (start != null) {
      _input.text = planTime(start);
      _nextDay = start >= 1440;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  int? get _start {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_input.text.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute + (_nextDay ? 1440 : 0);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final plan = widget.controller.cashierPlan;
      final shifts = plan.scheduledDay(widget.person.id, widget.date).shifts;
      final under18 = plan.field('under18')[widget.person.id] == true;
      final pause = calculateCashierBreak(
        shifts,
        under18: under18,
        start: _start,
      );
      final formatError = _input.text.isNotEmpty && _start == null
          ? 'Bitte eine Uhrzeit wie 12:30 eingeben.'
          : null;
      final error = _saveError ?? formatError ?? pause.error;
      final stored = plan.breakStart(widget.person.id, widget.date) != null;
      return AlertDialog(
        title: const Text('Pause eintragen'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.person.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.date.day}.${widget.date.month}.${widget.date.year} · ${under18 ? 'Unter 18 Jahre' : 'Ab 18 Jahre'}',
                ),
                const SizedBox(height: 4),
                Text(shifts.map((s) => s.label).join(' · ')),
                const SizedBox(height: 16),
                TextField(
                  controller: _input,
                  enabled: !_saving,
                  autofocus: !stored,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Pausenbeginn',
                    hintText: 'HH:mm',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  onChanged: (_) => setState(() => _saveError = null),
                  onSubmitted: (_) {
                    if (_start != null && error == null && pause.duration > 0) {
                      _save(_start);
                    }
                  },
                ),
                if (shifts.any((s) => s.end > 1440))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Beginn am Folgetag'),
                    value: _nextDay,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _nextDay = value!;
                            _saveError = null;
                          }),
                  ),
                const SizedBox(height: 12),
                Text(
                  pause.duration == 0
                      ? 'Keine gesetzliche Pflichtpause erforderlich.'
                      : '${pause.duration} Minuten Pause${pause.interval == null ? '' : ' · ${pause.interval!.label}'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Die Pausenzeit wird von der Schichtzeit abgezogen. Die Länge wird automatisch berechnet.',
                  style: TextStyle(fontSize: 12),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (stored)
            TextButton(
              onPressed: _saving ? null : () => _save(null),
              child: const Text('Pause entfernen'),
            ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed:
                _saving ||
                    !widget.controller.canEdit ||
                    _start == null ||
                    error != null ||
                    pause.duration == 0
                ? null
                : () => _save(_start),
            child: Text(_saving ? 'Speichert …' : 'Speichern'),
          ),
        ],
      );
    },
  );

  Future<void> _save(int? start) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (widget.controller.repository.marketSession?.marketId != _marketId) {
        throw StateError('Der Markt wurde gewechselt.');
      }
      if (!widget.controller.canEdit) {
        throw StateError('Der Marktzugang ist schreibgeschützt.');
      }
      if (start != null) {
        final current = widget.controller.cashierPlan;
        final result = calculateCashierBreak(
          current.scheduledDay(widget.person.id, widget.date).shifts,
          under18: current.field('under18')[widget.person.id] == true,
          start: start,
        );
        if (result.error != null || result.duration == 0) {
          throw StateError(
            result.error ?? 'Für diesen Tag ist keine Pause vorgesehen.',
          );
        }
      }
      await widget.controller.saveCashierPlanPatch({
        // A null tombstone also removes a saved pause on other devices.
        'breaks': {'${planDateKey(widget.date)}|${widget.person.id}': start},
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = '$error';
        });
      }
    }
  }
}
