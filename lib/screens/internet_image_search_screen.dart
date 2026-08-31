import 'package:flutter/material.dart';

import '../data/image_suggestion_service.dart';

class InternetImageSearchScreen extends StatefulWidget {
  const InternetImageSearchScreen({required this.initialQuery, super.key});

  final String initialQuery;

  @override
  State<InternetImageSearchScreen> createState() =>
      _InternetImageSearchScreenState();
}

class _InternetImageSearchScreenState extends State<InternetImageSearchScreen> {
  final _service = const ImageSuggestionService();
  late final TextEditingController _queryController;
  Future<List<RemoteImageSuggestion>>? _results;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildvorschläge')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Produktsuche',
                prefixIcon: const Icon(Icons.image_search),
                suffixIcon: IconButton(
                  tooltip: 'Suchen',
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<RemoteImageSuggestion>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _SearchMessage(
                    icon: Icons.cloud_off_outlined,
                    text:
                        'Bildvorschläge konnten nicht geladen werden.\n'
                        '${snapshot.error}',
                    action: _search,
                  );
                }
                final results = snapshot.data ?? const [];
                if (results.isEmpty) {
                  return _SearchMessage(
                    icon: Icons.image_not_supported_outlined,
                    text:
                        'Keine passenden Bilder gefunden. Versuche einen '
                        'allgemeineren Produktnamen.',
                    action: null,
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .82,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final suggestion = results[index];
                    return Card(
                      child: InkWell(
                        onTap: () => Navigator.pop(context, suggestion),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Image.network(
                                suggestion.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Colors.black12,
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestion.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    suggestion.license ?? 'Wikimedia Commons',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(16, 5, 16, 10),
            child: Text(
              'Vorschläge und Lizenzangaben: Wikimedia Commons',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _search() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() => _results = _service.search(query));
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.text,
    required this.action,
  });

  final IconData icon;
  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
