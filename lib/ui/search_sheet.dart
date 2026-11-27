import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/library_groups.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isFolder,
    this.app,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isFolder;
  final AppRecord? app;
}

List<SearchHit> searchLibrary(
  LibraryController controller, {
  required LibraryGroupMode mode,
  required String query,
}) {
  final needle = query.trim().toLowerCase();
  final hits = <SearchHit>[];
  for (final section in controller.librarySections(mode)) {
    final folderId = folderFocusId(section.title);
    if (needle.isEmpty || section.title.toLowerCase().contains(needle)) {
      hits.add(
        SearchHit(
          id: folderId,
          title: section.title,
          subtitle: 'Folder · ${section.apps.length}',
          isFolder: true,
        ),
      );
    }
    for (final app in section.apps) {
      if (needle.isEmpty || app.displayName.toLowerCase().contains(needle)) {
        hits.add(
          SearchHit(
            id: app.id,
            title: app.displayName,
            subtitle: section.title,
            isFolder: false,
            app: app,
          ),
        );
      }
    }
  }
  return hits;
}

class GlobalSearchSheet extends StatefulWidget {
  const GlobalSearchSheet({
    super.key,
    required this.controller,
    required this.mode,
    required this.scale,
    required this.onClose,
    required this.onOpenFolder,
    required this.onOpenApp,
  });

  final LibraryController controller;
  final LibraryGroupMode mode;
  final double scale;
  final VoidCallback onClose;
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<AppRecord> onOpenApp;

  @override
  State<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<GlobalSearchSheet> {
  final _query = TextEditingController();
  var _index = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = searchLibrary(
      widget.controller,
      mode: widget.mode,
      query: _query.text,
    );
    if (_index >= hits.length) {
      _index = 0;
    }
    return Actions(
      actions: {
        DismissOverlayIntent: CallbackAction<DismissOverlayIntent>(
          onInvoke: (_) {
            widget.onClose();
            return null;
          },
        ),
      },
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 640),
            child: Material(
              key: const Key('global-search'),
              color: const Color(0xFF1B2433),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: HomeDeckColors.cyan, width: 2),
              ),
              child: Padding(
                padding: EdgeInsets.all(22 * widget.scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('search-field'),
                      controller: _query,
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search ROMs, consoles, apps, and folders',
                      ),
                      onChanged: (_) => setState(() => _index = 0),
                      onSubmitted: (_) => _activate(hits),
                    ),
                    SizedBox(height: 8 * widget.scale),
                    Text(
                      'Press A to open   Press X to navigate   Press B to close',
                      style: TextStyle(
                        color: HomeDeckColors.muted,
                        fontSize: 12 * widget.scale,
                      ),
                    ),
                    SizedBox(height: 8 * widget.scale),
                    Expanded(
                      child: hits.isEmpty
                          ? const Center(child: Text('No matches'))
                          : ListView.builder(
                              itemCount: hits.length,
                              itemBuilder: (context, index) {
                                final hit = hits[index];
                                final selected = index == _index;
                                return ListTile(
                                  key: Key('search-hit-${hit.id}'),
                                  selected: selected,
                                  title: Text(hit.title),
                                  subtitle: Text(hit.subtitle),
                                  trailing: Text(
                                    hit.isFolder ? 'Folder' : 'ROM',
                                    style: const TextStyle(
                                      color: HomeDeckColors.muted,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() => _index = index);
                                    _open(hit);
                                  },
                                );
                              },
                            ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: widget.onClose,
                        child: const Text('Close  ·  B'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activate(List<SearchHit> hits) {
    if (hits.isEmpty) {
      return;
    }
    _open(hits[_index.clamp(0, hits.length - 1)]);
  }

  void _open(SearchHit hit) {
    if (hit.isFolder) {
      widget.onOpenFolder(hit.title);
    } else if (hit.app != null) {
      widget.onOpenApp(hit.app!);
    }
  }
}
