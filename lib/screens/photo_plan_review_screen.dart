import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../data/photo_plan_import.dart';
import '../models/cashier_plan.dart';

class PhotoPlanReviewScreen extends StatefulWidget {
  const PhotoPlanReviewScreen({
    super.key,
    required this.draft,
    required this.existing,
    required this.fileName,
    required this.photo,
  });
  final PhotoPlanImport draft;
  final CashierPlan existing;
  final String fileName;
  final Uint8List photo;

  @override
  State<PhotoPlanReviewScreen> createState() => _PhotoPlanReviewScreenState();
}

class _PhotoPlanReviewScreenState extends State<PhotoPlanReviewScreen> {
  String? _error;
  String _date(DateTime date) {
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return '${weekdays[date.weekday - 1]}, ${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Fotoimport prüfen'),
      actions: [
        IconButton(
          tooltip: 'Originalfoto ansehen',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(title: const Text('Originalfoto')),
                body: InteractiveViewer(
                  maxScale: 8,
                  child: Center(child: Image.memory(widget.photo)),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.image_outlined),
        ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Bitte Namen, Tage und Schichten mit dem Foto vergleichen. Nur ausgewählte Einträge werden übernommen.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pausen werden nicht importiert. Bereits eingetragene Pausen und Rollen bleiben erhalten. Leere Felder werden ausgelassen; für einen ausdrücklich freien Tag „FREI“ eintragen.',
            ),
            for (final warning in widget.draft.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  warning,
                  style: const TextStyle(color: Color(0xFF865500)),
                ),
              ),
            const SizedBox(height: 16),
            for (final row in widget.draft.rows) _person(row),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: FilledButton.icon(
        onPressed: widget.draft.selectedCount == 0 ? null : _confirm,
        icon: const Icon(Icons.check),
        label: Text(
          '${widget.draft.selectedCount} ${widget.draft.selectedCount == 1 ? 'Eintrag' : 'Einträge'} übernehmen',
        ),
      ),
    ),
  );

  Widget _person(PhotoPlanRow row) {
    final person = photoPlanPerson(widget.existing, row.name);
    final corrections = row.cells
        .where((cell) => cell.text.isNotEmpty && cell.error != null)
        .length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        key: ObjectKey(row),
        title: Text(
          row.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            '${row.cells.where((cell) => cell.selected).length} ausgewählt',
            if (person == null) 'Neue Person · zunächst ausgeblendet',
            if (corrections > 0)
              '$corrections ${corrections == 1 ? 'Angabe' : 'Angaben'} prüfen',
          ].join(' · '),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _editName(row),
              icon: const Icon(Icons.person_outline),
              label: const Text('Person zuordnen / Namen ändern'),
            ),
          ),
          for (final cell in row.cells) _entry(row, cell, person),
        ],
      ),
    );
  }

  Widget _entry(PhotoPlanRow row, PhotoPlanCell cell, CashierPerson? person) {
    final error = cell.error;
    final key =
        '${planDateKey(cell.date)}|${person?.id ?? planPersonId(row.name)}';
    final old = widget.existing.field('days')[key];
    String? previous;
    if (old is Map && error == null) {
      final oldDay = CashierDay.fromJson(Map<String, dynamic>.from(old));
      final day = parsePhotoPlanDay(cell.text);
      if (oldDay.note != day.note ||
          oldDay.shifts.map((shift) => shift.label).join(', ') !=
              day.shifts.map((shift) => shift.label).join(', ')) {
        previous = oldDay.shifts.isEmpty
            ? oldDay.status
            : oldDay.shifts.map((shift) => shift.label).join(', ');
      }
    }
    return ListTile(
      leading: Checkbox(
        value: cell.selected,
        onChanged: error != null
            ? null
            : (value) => setState(() => cell.selected = value ?? false),
      ),
      title: Text(
        '${_date(cell.date)} · ${cell.text.isEmpty ? 'Leer' : cell.text}',
      ),
      subtitle: error != null
          ? Text(
              error,
              style: TextStyle(
                color: cell.text.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
            )
          : previous != null
          ? Text('Ersetzt: $previous')
          : null,
      trailing: IconButton(
        tooltip: 'Eintrag bearbeiten',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => _editCell(cell),
      ),
      onTap: () => _editCell(cell),
    );
  }

  Future<void> _editCell(PhotoPlanCell cell) async {
    final controller = TextEditingController(text: cell.text);
    final form = GlobalKey<FormState>();
    final value = await _showEditor(
      controller,
      (context) => AlertDialog(
        title: Text(_date(cell.date)),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Schicht oder Abwesenheit',
              hintText: '06:00–14:00 oder ABW/FREI',
            ),
            validator: (value) {
              try {
                parsePhotoPlanDay(value ?? '');
                return null;
              } on FormatException catch (error) {
                return error.message;
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Anwenden'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    setState(() {
      cell.text = value;
      cell.selected = true;
    });
  }

  Future<void> _editName(PhotoPlanRow row) async {
    final controller = TextEditingController(text: row.name);
    final value = await _showEditor(
      controller,
      (context) => AlertDialog(
        title: const Text('Person zuordnen'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Nachname, Vorname',
                  ),
                ),
                if (widget.existing.people.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Vorhandene Person auswählen',
                    ),
                    items: [
                      for (final person in widget.existing.people)
                        DropdownMenuItem(
                          value: person.id,
                          child: Text(person.displayName),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) {
                        controller.text = widget.existing.people
                            .firstWhere((person) => person.id == id)
                            .name;
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Anwenden'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    setState(() => row.name = value);
  }

  Future<String?> _showEditor(
    TextEditingController controller,
    WidgetBuilder builder,
  ) {
    final route = DialogRoute<String>(context: context, builder: builder);
    // Dispose after the route's closing animation, when its fields unmount.
    unawaited(route.completed.then((_) => controller.dispose()));
    return Navigator.of(context).push(route);
  }

  void _confirm() {
    try {
      final patch = widget.draft.toPatch(
        existing: widget.existing,
        fileName: widget.fileName,
      );
      Navigator.pop(context, patch);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }
}
