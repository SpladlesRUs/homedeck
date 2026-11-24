import 'dart:async';
import 'dart:io';

import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/library_groups.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:homedeck/ui/platform_folder.dart';
import 'package:material_ui/material_ui.dart';

/// Settle delay before the folder hero crossfades. Tests set this to zero.
class FolderHero {
  static Duration settle = const Duration(milliseconds: 350);
}

class LibraryView extends StatelessWidget {
  const LibraryView({
    super.key,
    required this.controller,
    required this.metrics,
    required this.mode,
    required this.focusedId,
    required this.hoveredId,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.onAdd,
    required this.onMode,
    required this.focusNodeFor,
    this.openFolderTitle,
    this.onOpenFolder,
    this.onCloseFolder,
    this.chipsFocused = false,
  });

  final LibraryController controller;
  final HomeDeckMetrics metrics;
  final LibraryGroupMode mode;
  final String? focusedId;
  final String? hoveredId;
  final bool chipsFocused;
  final String? openFolderTitle;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final VoidCallback onAdd;
  final ValueChanged<LibraryGroupMode> onMode;
  final ValueChanged<String>? onOpenFolder;
  final VoidCallback? onCloseFolder;
  final FocusNode Function(String id) focusNodeFor;

  @override
  Widget build(BuildContext context) {
    final sections = controller.librarySections(mode);
    LibrarySection? open;
    if (openFolderTitle != null) {
      for (final section in sections) {
        if (section.title == openFolderTitle) {
          open = section;
          break;
        }
      }
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            16 * metrics.scale,
            10 * metrics.scale,
            16 * metrics.scale,
            4 * metrics.scale,
          ),
          child: _GroupChips(
            metrics: metrics,
            mode: mode,
            focused: chipsFocused,
            folderOpen: open != null,
            onMode: onMode,
            onBack: onCloseFolder,
          ),
        ),
        Expanded(
          child: open != null
              ? FolderInterior(
                  section: open,
                  controller: controller,
                  metrics: metrics,
                  focusedId: focusedId,
                  hoveredId: hoveredId,
                  onFocus: onFocus,
                  onHover: onHover,
                  onLaunch: onLaunch,
                  focusNodeFor: focusNodeFor,
                )
              : _FolderGrid(
                  sections: sections,
                  metrics: metrics,
                  focusedId: focusedId,
                  hoveredId: hoveredId,
                  onFocus: onFocus,
                  onHover: onHover,
                  onOpen: (title) => onOpenFolder?.call(title),
                  onAdd: onAdd,
                  focusNodeFor: focusNodeFor,
                ),
        ),
      ],
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.metrics,
    required this.mode,
    required this.focused,
    required this.folderOpen,
    required this.onMode,
    this.onBack,
  });

  final HomeDeckMetrics metrics;
  final LibraryGroupMode mode;
  final bool focused;
  final bool folderOpen;
  final ValueChanged<LibraryGroupMode> onMode;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (folderOpen && onBack != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              key: const Key('library-folder-back'),
              onPressed: onBack,
              child: const Text('Folders  ·  B'),
            ),
          ),
        for (final value in LibraryGroupMode.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: Key('library-mode-${value.name}'),
              label: Text(value.label),
              selected: mode == value,
              onSelected: folderOpen ? null : (_) => onMode(value),
            ),
          ),
        const Spacer(),
        const HintBadge(label: 'X'),
      ],
    );
  }
}

class _FolderGrid extends StatelessWidget {
  const _FolderGrid({
    required this.sections,
    required this.metrics,
    required this.focusedId,
    required this.hoveredId,
    required this.onFocus,
    required this.onHover,
    required this.onOpen,
    required this.onAdd,
    required this.focusNodeFor,
  });

  final List<LibrarySection> sections;
  final HomeDeckMetrics metrics;
  final String? focusedId;
  final String? hoveredId;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<String> onOpen;
  final VoidCallback onAdd;
  final FocusNode Function(String id) focusNodeFor;

  @override
  Widget build(BuildContext context) {
    final columns = metrics.libraryFolderColumns;
    final cells = <LibrarySection?>[...sections, null];
    if (sections.isEmpty) {
      return Center(
        child: Text(
          'Library is empty. Add a game from Menu.',
          style: TextStyle(
            color: HomeDeckColors.muted,
            fontSize: 16 * metrics.scale,
          ),
        ),
      );
    }
    return Padding(
      key: const Key('library-folders'),
      padding: EdgeInsets.all(16 * metrics.scale),
      child: GridView.builder(
        itemCount: cells.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 1,
          mainAxisSpacing: metrics.gap,
          crossAxisSpacing: metrics.gap,
        ),
        itemBuilder: (context, index) => _cell(cells, index),
      ),
    );
  }

  Widget _cell(List<LibrarySection?> cells, int index) {
    final section = cells[index];
    if (section == null) {
      return AddTile(
        key: const ValueKey('tile-add'),
        metrics: metrics,
        focused: focusedId == addTileId,
        hovered: hoveredId == addTileId,
        focusNode: focusNodeFor(addTileId),
        onActivate: onAdd,
        onFocus: () => onFocus(addTileId),
        onHover: (hover) => onHover(hover ? addTileId : null),
      );
    }
    final id = folderFocusId(section.title);
    return FolderTile(
      key: Key('folder-${slugForGroupTitle(section.title)}'),
      title: section.title,
      slug: slugForGroupTitle(section.title),
      count: section.apps.length,
      metrics: metrics,
      focused: focusedId == id,
      focusNode: focusNodeFor(id),
      onFocus: () => onFocus(id),
      onHover: (hover) => onHover(hover ? id : null),
      onOpen: () => onOpen(section.title),
    );
  }
}

class FolderInterior extends StatefulWidget {
  const FolderInterior({
    super.key,
    required this.section,
    required this.controller,
    required this.metrics,
    required this.focusedId,
    required this.hoveredId,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.focusNodeFor,
  });

  final LibrarySection section;
  final LibraryController controller;
  final HomeDeckMetrics metrics;
  final String? focusedId;
  final String? hoveredId;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final FocusNode Function(String id) focusNodeFor;

  @override
  State<FolderInterior> createState() => _FolderInteriorState();
}

class _FolderInteriorState extends State<FolderInterior> {
  String? _heroId;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    _queueHero(widget.focusedId);
  }

  @override
  void didUpdateWidget(FolderInterior oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedId != widget.focusedId ||
        oldWidget.section.title != widget.section.title) {
      _queueHero(widget.focusedId);
    }
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  void _queueHero(String? id) {
    _settle?.cancel();
    if (FolderHero.settle == Duration.zero) {
      setState(() => _heroId = id);
      return;
    }
    _settle = Timer(FolderHero.settle, () {
      if (mounted) {
        setState(() => _heroId = id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apps = widget.section.apps;
    final columns = widget.metrics.insideFolderColumns;
    AppRecord? heroApp;
    for (final app in apps) {
      if (app.id == _heroId) {
        heroApp = app;
        break;
      }
    }
    heroApp ??= apps.isEmpty ? null : apps.first;
    final File? art = heroApp == null
        ? null
        : widget.controller.iconFile(heroApp);
    return Stack(
      key: const Key('folder-interior'),
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          child: Transform.scale(
            key: ValueKey(_heroId ?? 'none'),
            scale: 1.06,
            child: ArtBackdrop(
              color: backdropColorFor(_heroId ?? widget.section.title),
              imageFile: art,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(16 * widget.metrics.scale),
                child: GridView.builder(
                  itemCount: apps.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 1,
                    mainAxisSpacing: widget.metrics.gap,
                    crossAxisSpacing: widget.metrics.gap,
                  ),
                  itemBuilder: (context, index) => _tile(apps, index),
                ),
              ),
            ),
            const Expanded(flex: 4, child: SizedBox.expand()),
          ],
        ),
      ],
    );
  }

  Widget _tile(List<AppRecord> apps, int index) {
    if (index >= apps.length) {
      return const SizedBox.expand();
    }
    final app = apps[index];
    return AppTile(
      key: ValueKey('tile-${app.id}'),
      app: app,
      metrics: widget.metrics,
      iconFile: widget.controller.iconFile(app),
      focused: widget.focusedId == app.id,
      hovered: widget.hoveredId == app.id,
      moveMode: false,
      focusNode: widget.focusNodeFor(app.id),
      onActivate: () => widget.onLaunch(app),
      onFocus: () => widget.onFocus(app.id),
      onHover: (hover) => widget.onHover(hover ? app.id : null),
    );
  }
}
