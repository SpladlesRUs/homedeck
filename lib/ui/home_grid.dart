import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

const addTileId = '__homedeck_add__';

class HomeGrid extends StatelessWidget {
  const HomeGrid({
    super.key,
    required this.controller,
    required this.metrics,
    required this.page,
    required this.focusedId,
    required this.hoveredId,
    required this.moveMode,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.onAdd,
    required this.onReorderDrop,
    required this.focusNodeFor,
    this.hideEmpty = false,
  });

  final LibraryController controller;
  final HomeDeckMetrics metrics;
  final int page;
  final String? focusedId;
  final String? hoveredId;
  final bool moveMode;
  final bool hideEmpty;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final VoidCallback onAdd;
  final void Function(String draggedId, String ontoId) onReorderDrop;
  final FocusNode Function(String id) focusNodeFor;

  static int pageCountFor(int occupied, int pageSize) {
    if (occupied <= 0) {
      return 1;
    }
    return ((occupied + pageSize - 1) / pageSize).floor().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    final apps = controller.apps;
    final pageSize = metrics.pageSize;
    final start = page * pageSize;
    return Padding(
      padding: EdgeInsets.all(16 * metrics.scale),
      child: Column(
        children: [
          for (var row = 0; row < metrics.rows; row++) ...[
            if (row > 0) SizedBox(height: metrics.gap),
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < metrics.columns; col++) ...[
                    if (col > 0) SizedBox(width: metrics.gap),
                    Expanded(
                      child: _slot(
                        start + row * metrics.columns + col,
                        apps,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slot(int index, List<AppRecord> apps) {
    if (index < apps.length) {
      final app = apps[index];
      return AppTile(
        key: ValueKey('tile-${app.id}'),
        app: app,
        metrics: metrics,
        iconFile: controller.iconFile(app),
        focused: focusedId == app.id,
        hovered: hoveredId == app.id,
        moveMode: moveMode,
        autofocus: index == 0 && focusedId == null,
        focusNode: focusNodeFor(app.id),
        onActivate: () => onLaunch(app),
        onFocus: () => onFocus(app.id),
        onHover: (hover) => onHover(hover ? app.id : null),
        onDroppedOn: (dragged) => onReorderDrop(dragged, app.id),
      );
    }
    if (index == apps.length) {
      return AddTile(
        key: const ValueKey('tile-add'),
        metrics: metrics,
        focused: focusedId == addTileId,
        hovered: hoveredId == addTileId,
        autofocus: apps.isEmpty && focusedId == null,
        focusNode: focusNodeFor(addTileId),
        onActivate: onAdd,
        onHover: (hover) => onHover(hover ? addTileId : null),
        onFocus: () => onFocus(addTileId),
      );
    }
    if (hideEmpty) {
      return const SizedBox.expand();
    }
    return EmptySlot(
      key: ValueKey('empty-slot-$index'),
      metrics: metrics,
    );
  }
}
