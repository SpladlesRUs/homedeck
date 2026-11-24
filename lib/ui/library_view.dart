import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:material_ui/material_ui.dart';

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
    this.chipsFocused = false,
  });

  final LibraryController controller;
  final HomeDeckMetrics metrics;
  final LibraryGroupMode mode;
  final String? focusedId;
  final String? hoveredId;
  final bool chipsFocused;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final VoidCallback onAdd;
  final ValueChanged<LibraryGroupMode> onMode;
  final FocusNode Function(String id) focusNodeFor;

  @override
  Widget build(BuildContext context) {
    final sections = controller.librarySections(mode);
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
            onMode: onMode,
          ),
        ),
        Expanded(
          child: sections.isEmpty
              ? Center(
                  child: Text(
                    'Library is empty. Add a game from Menu.',
                    style: TextStyle(
                      color: HomeDeckColors.muted,
                      fontSize: 16 * metrics.scale,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  key: const Key('library-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    16 * metrics.scale,
                    8 * metrics.scale,
                    16 * metrics.scale,
                    16 * metrics.scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final section in sections) ...[
                        _SectionHeader(title: section.title, metrics: metrics),
                        SizedBox(height: 8 * metrics.scale),
                        _SectionGrid(
                          apps: section.apps,
                          controller: controller,
                          metrics: metrics,
                          focusedId: focusedId,
                          hoveredId: hoveredId,
                          onFocus: onFocus,
                          onHover: onHover,
                          onLaunch: onLaunch,
                          focusNodeFor: focusNodeFor,
                        ),
                        SizedBox(height: 16 * metrics.scale),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 96 * metrics.scale,
                          height: 96 * metrics.scale,
                          child: AddTile(
                            key: const ValueKey('tile-add'),
                            metrics: metrics,
                            focused: focusedId == addTileId,
                            hovered: hoveredId == addTileId,
                            focusNode: focusNodeFor(addTileId),
                            onActivate: onAdd,
                            onFocus: () => onFocus(addTileId),
                            onHover: (hover) =>
                                onHover(hover ? addTileId : null),
                          ),
                        ),
                      ),
                    ],
                  ),
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
    required this.onMode,
  });

  final HomeDeckMetrics metrics;
  final LibraryGroupMode mode;
  final bool focused;
  final ValueChanged<LibraryGroupMode> onMode;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.metrics});

  final String title;
  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      key: Key('library-section-$title'),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 16 * metrics.scale,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.apps,
    required this.controller,
    required this.metrics,
    required this.focusedId,
    required this.hoveredId,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.focusNodeFor,
  });

  final List<AppRecord> apps;
  final LibraryController controller;
  final HomeDeckMetrics metrics;
  final String? focusedId;
  final String? hoveredId;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final FocusNode Function(String id) focusNodeFor;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: apps.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.columns,
        mainAxisSpacing: metrics.gap,
        crossAxisSpacing: metrics.gap,
      ),
      itemBuilder: (context, index) {
        final app = apps[index];
        return AppTile(
          key: ValueKey('tile-${app.id}'),
          app: app,
          metrics: metrics,
          iconFile: controller.iconFile(app),
          focused: focusedId == app.id,
          hovered: hoveredId == app.id,
          moveMode: false,
          focusNode: focusNodeFor(app.id),
          onActivate: () => onLaunch(app),
          onFocus: () => onFocus(app.id),
          onHover: (hover) => onHover(hover ? app.id : null),
        );
      },
    );
  }
}
