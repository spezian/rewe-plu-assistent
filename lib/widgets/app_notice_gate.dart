import 'package:material_ui/material_ui.dart';

import '../data/product_repository.dart';

class AppNoticeGate extends StatefulWidget {
  const AppNoticeGate({
    required this.repository,
    required this.child,
    super.key,
  });

  final ProductRepository repository;
  final Widget child;

  @override
  State<AppNoticeGate> createState() => _AppNoticeGateState();
}

class _AppNoticeGateState extends State<AppNoticeGate> {
  @override
  void initState() {
    super.initState();
    if (widget.repository.hasAcknowledgedAppNotice) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AppNoticeDialog(
          onAcknowledge: widget.repository.acknowledgeAppNotice,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppNoticeDialog extends StatefulWidget {
  const _AppNoticeDialog({required this.onAcknowledge});

  final Future<void> Function() onAcknowledge;

  @override
  State<_AppNoticeDialog> createState() => _AppNoticeDialogState();
}

class _AppNoticeDialogState extends State<_AppNoticeDialog> {
  bool _saving = false;
  bool _saveFailed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: const Text('Hinweis zur App'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diese App ist ein inoffizielles Projekt und keine '
              'offiziell gewartete App. Sie wird ausschließlich von Dacjan '
              'gewartet.\n\n'
              'Die hinterlegten PLUs und anderen Codes können fehlerhaft oder '
              'veraltet sein. Fehler bitte gerne melden.\n\n'
              'Vergiss nicht, glotzt nicht zu viel auf dein Handy!',
            ),
            if (_saveFailed) ...[
              const SizedBox(height: 16),
              Text(
                'Die Bestätigung konnte nicht gespeichert werden. '
                'Bitte versuche es erneut.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: _saving ? null : _acknowledge,
            child: Text(_saving ? 'Wird gespeichert …' : 'Verstanden'),
          ),
        ],
      ),
    );
  }

  Future<void> _acknowledge() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onAcknowledge();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }
}
