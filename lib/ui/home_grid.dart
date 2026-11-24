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
    required this.focusedId,
    required this.hoveredId,
    required this.moveMode,
    required this.onFocus,
    required this.onHover,
    required this.onLaunch,
    required this.onAdd,
    required this.onReorderDrop,
    required this.focusNodeFor,
  });

  final LibraryController controller;
  final HomeDeckMetrics metrics;
  final String? focusedId;
  final String? hoveredId;
  final bool moveMode;
  final ValueChanged<String> onFocus;
  final ValueChanged<String?> onHover;
  final ValueChanged<AppRecord> onLaunch;
  final VoidCallback onAdd;
  final void Function(String draggedId, String ontoId) onReorderDrop;
  final FocusNode Function(String id) focusNodeFor;

  @override
  Widget build(BuildContext context) {
    final apps = controller.apps;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = constraints.maxWidth - metrics.padding * 2;
        final tileWidth =
            (inner - metrics.gap * (metrics.columns - 1)) / metrics.columns;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.padding,
            vertical: 8 * metrics.scale,
          ),
          child: Wrap(
            spacing: metrics.gap,
            runSpacing: metrics.gap + 12 * metrics.scale,
            children: [
              for (var i = 0; i < apps.length; i++)
                SizedBox(
                  key: ValueKey('tile-${apps[i].id}'),
                  width: tileWidth,
                  child: AppTile(
                    app: apps[i],
                    metrics: metrics,
                    iconFile: controller.iconFile(apps[i]),
                    focused: focusedId == apps[i].id,
                    hovered: hoveredId == apps[i].id,
                    moveMode: moveMode,
                    autofocus: i == 0 && focusedId == null,
                    focusNode: focusNodeFor(apps[i].id),
                    onActivate: () => onLaunch(apps[i]),
                    onFocus: () => onFocus(apps[i].id),
                    onHover: (hover) => onHover(hover ? apps[i].id : null),
                    onDroppedOn: (dragged) => onReorderDrop(dragged, apps[i].id),
                  ),
                ),
              SizedBox(
                key: const ValueKey('tile-add'),
                width: tileWidth,
                child: AddTile(
                  metrics: metrics,
                  focused: focusedId == addTileId,
                  hovered: hoveredId == addTileId,
                  autofocus: apps.isEmpty && focusedId == null,
                  focusNode: focusNodeFor(addTileId),
                  onActivate: onAdd,
                  onFocus: () => onFocus(addTileId),
                  onHover: (hover) => onHover(hover ? addTileId : null),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
