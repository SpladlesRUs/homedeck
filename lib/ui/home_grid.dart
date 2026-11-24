import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:homedeck/ui/now_playing_tile.dart';
import 'package:material_ui/material_ui.dart';

const addTileId = '__homedeck_add__';

String emptySlotId(int index) => '__homedeck_empty_$index';

bool isEmptySlotId(String id) => id.startsWith('__homedeck_empty_');

int? emptySlotIndex(String id) {
  if (!isEmptySlotId(id)) {
    return null;
  }
  return int.tryParse(id.substring('__homedeck_empty_'.length));
}

class HomeGrid extends StatelessWidget {
  const HomeGrid({
    super.key,
    required this.controller,
    required this.metrics,
    required this.slots,
    required this.pageStart,
    required this.columns,
    required this.focusedId,
    required this.hoveredId,
    required this.moveMode,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.onEmptyActivate,
    required this.onReorderDrop,
    required this.focusNodeFor,
    this.featured,
  });

  final LibraryController controller;
  final HomeDeckMetrics metrics;

  /// Current page of Home slots. Nulls are empty desktop cells.
  final List<String?> slots;
  final int pageStart;
  final int columns;
  final String? focusedId;
  final String? hoveredId;
  final bool moveMode;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final ValueChanged<int> onEmptyActivate;
  final void Function(String draggedId, String ontoId) onReorderDrop;
  final FocusNode Function(String id) focusNodeFor;
  final Widget? featured;

  static int pageCountFor(int occupied, int pageSize) {
    if (occupied <= 0) {
      return 1;
    }
    return ((occupied + pageSize - 1) / pageSize).floor().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    final grid = Padding(
      padding: EdgeInsets.all(16 * metrics.scale),
      child: Column(
        children: [
          for (var row = 0; row < metrics.rows; row++) ...[
            if (row > 0) SizedBox(height: metrics.gap),
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) SizedBox(width: metrics.gap),
                    Expanded(child: _cell(row * columns + col)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
    if (featured == null) {
      return grid;
    }
    return Row(
      children: [
        Expanded(flex: 3, child: featured!),
        Expanded(flex: 5, child: grid),
      ],
    );
  }

  Widget _cell(int local) {
    final index = pageStart + local;
    final id = local < slots.length ? slots[local] : null;
    if (id != null) {
      final app = controller.byId(id);
      if (app != null) {
        return AppTile(
          key: ValueKey('tile-${app.id}'),
          app: app,
          metrics: metrics,
          iconFile: controller.iconFile(app),
          focused: focusedId == app.id,
          hovered: hoveredId == app.id,
          moveMode: moveMode,
          autofocus: false,
          focusNode: focusNodeFor(app.id),
          onActivate: () => onLaunch(app),
          onFocus: () => onFocus(app.id),
          onHover: (hover) => onHover(hover ? app.id : null),
          onDroppedOn: (dragged) => onReorderDrop(dragged, app.id),
        );
      }
    }
    final emptyId = emptySlotId(index);
    return EmptySlot(
      key: ValueKey('home-slot-$index'),
      metrics: metrics,
      focused: focusedId == emptyId,
      hovered: hoveredId == emptyId,
      moveMode: moveMode,
      autofocus: false,
      focusNode: focusNodeFor(emptyId),
      onActivate: () => onEmptyActivate(index),
      onFocus: () => onFocus(emptyId),
      onHover: (hover) => onHover(hover ? emptyId : null),
    );
  }
}

class HomePagedView extends StatelessWidget {
  const HomePagedView({
    super.key,
    required this.controller,
    required this.metrics,
    required this.slots,
    required this.page,
    required this.pages,
    required this.focusedId,
    required this.hoveredId,
    required this.moveMode,
    required this.music,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.onEmptyActivate,
    required this.onReorderDrop,
    required this.onPage,
    required this.focusNodeFor,
  });

  final LibraryController controller;
  final HomeDeckMetrics metrics;
  final List<String?> slots;
  final int page;
  final int pages;
  final String? focusedId;
  final String? hoveredId;
  final bool moveMode;
  final MenuMusicController? music;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final ValueChanged<int> onEmptyActivate;
  final void Function(String draggedId, String ontoId) onReorderDrop;
  final ValueChanged<int> onPage;
  final FocusNode Function(String id) focusNodeFor;

  @override
  Widget build(BuildContext context) {
    final start = metrics.homePageStart(page);
    final size = metrics.homePageSize(page);
    final columns = metrics.homeColumns(page);
    final pageSlots = [
      for (var i = 0; i < size; i++)
        start + i < slots.length ? slots[start + i] : null,
    ];
    final featured = page == 0
        ? Padding(
            padding: EdgeInsets.fromLTRB(
              16 * metrics.scale,
              16 * metrics.scale,
              8 * metrics.scale,
              16 * metrics.scale,
            ),
            child: NowPlayingTile(
              key: const Key('now-playing-tile'),
              metrics: metrics,
              music: music,
              focused: focusedId == nowPlayingId,
              focusNode: focusNodeFor(nowPlayingId),
              onFocus: () => onFocus(nowPlayingId),
              onActivate: () => music?.togglePause(),
            ),
          )
        : null;
    return Row(
      children: [
        PagePeek(
          key: const Key('home-peek-prev'),
          enabled: page > 0,
          leading: true,
          onTap: page > 0 ? () => onPage(page - 1) : null,
        ),
        Expanded(
          child: GlassPanel(
            child: HomeGrid(
              controller: controller,
              metrics: metrics,
              slots: pageSlots,
              pageStart: start,
              columns: columns,
              focusedId: focusedId,
              hoveredId: hoveredId,
              moveMode: moveMode,
              featured: featured,
              onFocus: onFocus,
              onHover: onHover,
              onLaunch: onLaunch,
              onEmptyActivate: onEmptyActivate,
              onReorderDrop: onReorderDrop,
              focusNodeFor: focusNodeFor,
            ),
          ),
        ),
        PagePeek(
          key: const Key('home-peek-next'),
          enabled: page < pages - 1,
          leading: false,
          onTap: page < pages - 1 ? () => onPage(page + 1) : null,
        ),
      ],
    );
  }
}

class PagePeek extends StatelessWidget {
  const PagePeek({
    super.key,
    required this.enabled,
    required this.leading,
    this.onTap,
  });

  final bool enabled;
  final bool leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox(width: 18);
    }
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        child: Align(
          alignment: leading ? Alignment.centerLeft : Alignment.centerRight,
          child: Icon(
            leading ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: Colors.white70,
            size: 28,
          ),
        ),
      ),
    );
  }
}
