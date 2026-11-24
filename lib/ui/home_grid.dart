import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
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
    required this.focusedId,
    required this.hoveredId,
    required this.moveMode,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.onEmptyActivate,
    required this.onReorderDrop,
    required this.focusNodeFor,
  });

  final LibraryController controller;
  final HomeDeckMetrics metrics;

  /// Current page of Home slots. Nulls are empty desktop cells.
  final List<String?> slots;
  final int pageStart;
  final String? focusedId;
  final String? hoveredId;
  final bool moveMode;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final ValueChanged<int> onEmptyActivate;
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
                    Expanded(child: _cell(row * metrics.columns + col)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
          autofocus: index == 0 && focusedId == null,
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
      autofocus: index == 0 && focusedId == null,
      focusNode: focusNodeFor(emptyId),
      onActivate: () => onEmptyActivate(index),
      onFocus: () => onFocus(emptyId),
      onHover: (hover) => onHover(hover ? emptyId : null),
    );
  }
}
