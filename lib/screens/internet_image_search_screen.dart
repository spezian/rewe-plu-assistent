import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_constants.dart';
import '../data/image_suggestion_service.dart';

class InternetImageSearchScreen extends StatefulWidget {
  const InternetImageSearchScreen({
    required this.initialQuery,
    this.service = const ImageSuggestionService(),
    super.key,
  });

  final String initialQuery;
  final ImageSuggestionService service;

  @override
  State<InternetImageSearchScreen> createState() =>
      _InternetImageSearchScreenState();
}

class _InternetImageSearchScreenState extends State<InternetImageSearchScreen> {
  late final TextEditingController _queryController;
  Future<List<RemoteImageSuggestion>>? _results;
  ImageSearchSource _source = ImageSearchSource.rewe;
  bool _selectionHandled = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _updateResults();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = widget.service.unavailableReason(_source);
    return DefaultTabController(
      length: ImageSearchSource.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bildvorschläge'),
          bottom: TabBar(
            onTap: (index) {
              final source = ImageSearchSource.values[index];
              if (source == _source) return;
              setState(() {
                _source = source;
                _updateResults();
              });
            },
            tabs: [
              for (final source in ImageSearchSource.values)
                Tab(text: source.label),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                maxLength: 120,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Produktsuche',
                  counterText: '',
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
              child: unavailable != null
                  ? _SearchMessage(
                      icon: Icons.settings_outlined,
                      text: unavailable,
                    )
                  : FutureBuilder<List<RemoteImageSuggestion>>(
                      // Reset old data/errors immediately on a new search or tab.
                      key: ObjectKey(_results),
                      future: _results,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _SearchMessage(
                            icon: Icons.cloud_off_outlined,
                            text: snapshot.error is ImageSearchException
                                ? snapshot.error.toString()
                                : 'Bildvorschläge konnten nicht geladen werden. '
                                      'Bitte erneut versuchen.',
                            action: _search,
                          );
                        }
                        if (_results == null) {
                          return const _SearchMessage(
                            icon: Icons.image_search,
                            text: 'Gib einen Produktnamen ein, um Bilder zu suchen.',
                          );
                        }
                        final results = snapshot.data ?? const [];
                        if (results.isEmpty) {
                          return const _SearchMessage(
                            icon: Icons.image_not_supported_outlined,
                            text:
                                'Keine passenden Bilder gefunden. Versuche einen '
                                'allgemeineren Produktnamen.',
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 280,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: .82,
                              ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final suggestion = results[index];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _selectSuggestion(suggestion),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ColoredBox(
                                        color: Colors.white,
                                        child: Image.network(
                                          suggestion.thumbnailUrl ??
                                              suggestion.imageUrl,
                                          semanticLabel:
                                              suggestion.title ??
                                              'Bild auswählen',
                                          fit: _source == ImageSearchSource.rewe
                                              ? BoxFit.contain
                                              : BoxFit.cover,
                                          headers: kIsWeb
                                              ? null
                                              : {'User-Agent': userAgent},
                                          errorBuilder: (_, _, _) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                    if (suggestion.title != null ||
                                        suggestion.attribution != null)
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Text(
                                          suggestion.title ??
                                              suggestion.attribution!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
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
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 5, 16, 10),
              child: _source == ImageSearchSource.rewe
                  ? TextButton.icon(
                      onPressed: _openReweSearch,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Quelle: REWE · Suche öffnen'),
                    )
                  : const Text(
                      'Bildquelle: Unsplash',
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateResults() {
    final query = _queryController.text.trim();
    _results =
        query.isEmpty || widget.service.unavailableReason(_source) != null
        ? null
        : widget.service.search(query, source: _source);
  }

  void _search() {
    FocusScope.of(context).unfocus();
    setState(_updateResults);
  }

  Future<void> _openReweSearch() async {
    try {
      final opened = await launchUrl(
        reweSearchPage(_queryController.text.trim()),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Report launch failures without losing the search or selected source.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Die REWE-Suche konnte nicht geöffnet werden.'),
      ),
    );
  }

  void _selectSuggestion(RemoteImageSuggestion suggestion) {
    if (_selectionHandled || !mounted) return;
    _selectionHandled = true;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(suggestion);
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
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
