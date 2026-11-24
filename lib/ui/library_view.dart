import 'dart:async';

import 'package:homedeck/core/generated_icon.dart';
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
    if (open != null) {
      return FolderInterior(
        section: open,
        controller: controller,
        metrics: metrics,
        focusedId: focusedId,
        hoveredId: hoveredId,
        onFocus: onFocus,
        onHover: onHover,
        onLaunch: onLaunch,
        onClose: onCloseFolder,
        focusNodeFor: focusNodeFor,
      );
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            20 * metrics.scale,
            10 * metrics.scale,
            20 * metrics.scale,
            4 * metrics.scale,
          ),
          child: _GroupChips(mode: mode, focused: chipsFocused, onMode: onMode),
        ),
        Expanded(
          child: _FolderGrid(
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
    required this.mode,
    required this.focused,
    required this.onMode,
  });

  final LibraryGroupMode mode;
  final bool focused;
  final ValueChanged<LibraryGroupMode> onMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: focused
            ? Border.all(color: HomeDeckColors.cyan.withValues(alpha: 0.7))
            : null,
      ),
      child: Row(
        children: [
          for (final value in LibraryGroupMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('library-mode-${value.name}'),
                label: Text(value.label),
                selected: mode == value,
                onSelected: (_) => onMode(value),
              ),
            ),
          const Spacer(),
          const HintBadge(label: 'X'),
        ],
      ),
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
    final rows = metrics.rows;
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
    final cells = <LibrarySection?>[...sections, null];
    return Padding(
      key: const Key('library-folders'),
      padding: EdgeInsets.fromLTRB(
        20 * metrics.scale,
        8 * metrics.scale,
        20 * metrics.scale,
        16 * metrics.scale,
      ),
      child: Column(
        children: [
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) SizedBox(height: metrics.gap),
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) SizedBox(width: metrics.gap),
                    Expanded(child: _cell(cells, row * columns + col)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(List<LibrarySection?> cells, int index) {
    if (index >= cells.length) {
      return const SizedBox.expand();
    }
    final section = cells[index];
    if (section == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          10 * metrics.scale,
          10 * metrics.scale,
          10 * metrics.scale,
          34 * metrics.scale,
        ),
        child: AddTile(
          key: const ValueKey('tile-add'),
          metrics: metrics,
          focused: focusedId == addTileId,
          hovered: hoveredId == addTileId,
          focusNode: focusNodeFor(addTileId),
          onActivate: onAdd,
          onFocus: () => onFocus(addTileId),
          onHover: (hover) => onHover(hover ? addTileId : null),
        ),
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
    this.onClose,
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
  final VoidCallback? onClose;

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
    final rows = widget.metrics.rows;
    AppRecord? heroApp;
    for (final app in apps) {
      if (app.id == _heroId) {
        heroApp = app;
        break;
      }
    }
    heroApp ??= apps.isEmpty ? null : apps.first;
    final color = backdropColorFor(heroApp?.id ?? widget.section.title);
    return Row(
      key: const Key('folder-interior'),
      children: [
        Expanded(
          flex: 45,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24 * widget.metrics.scale,
              8 * widget.metrics.scale,
              8 * widget.metrics.scale,
              16 * widget.metrics.scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FolderBreadcrumb(
                  title: widget.section.title,
                  scale: widget.metrics.scale,
                  onBack: widget.onClose,
                ),
                SizedBox(height: 10 * widget.metrics.scale),
                Expanded(
                  child: Column(
                    children: [
                      for (var row = 0; row < rows; row++) ...[
                        if (row > 0) SizedBox(height: widget.metrics.gap),
                        Expanded(
                          child: Row(
                            children: [
                              for (var col = 0; col < columns; col++) ...[
                                if (col > 0)
                                  SizedBox(width: widget.metrics.gap),
                                Expanded(
                                  child: _tile(apps, row * columns + col),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 55,
          child: _HeroPortrait(
            metrics: widget.metrics,
            app: heroApp,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _tile(List<AppRecord> apps, int index) {
    if (index >= apps.length) {
      return const SizedBox.expand();
    }
    final app = apps[index];
    return Padding(
      padding: EdgeInsets.all(6 * widget.metrics.scale),
      child: AppTile(
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
      ),
    );
  }
}

class _FolderBreadcrumb extends StatelessWidget {
  const _FolderBreadcrumb({
    required this.title,
    required this.scale,
    this.onBack,
  });

  final String title;
  final double scale;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC0F1722),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('library-folder-back'),
        onTap: onBack,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 7 * scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 18 * scale,
              ),
              SizedBox(width: 4 * scale),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13 * scale,
                ),
              ),
              Text(
                '  ·  B',
                style: TextStyle(
                  color: HomeDeckColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12 * scale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPortrait extends StatelessWidget {
  const _HeroPortrait({required this.metrics, required this.color, this.app});

  final HomeDeckMetrics metrics;
  final AppRecord? app;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8 * metrics.scale,
        20 * metrics.scale,
        32 * metrics.scale,
        24 * metrics.scale,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOut,
        child: Align(
          key: ValueKey(app?.id ?? 'none'),
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: 0.78,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, Color.lerp(color, Colors.black, 0.4)!],
                      ),
                    ),
                  ),
                  if (app != null)
                    Center(
                      child: Text(
                        initialFor(app!.displayName),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 88 * metrics.scale,
                          shadows: const [
                            Shadow(color: Color(0x88000000), blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x73000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
