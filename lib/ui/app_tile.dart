import 'dart:io';
import 'dart:math' as math;

import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.app,
    required this.metrics,
    required this.focused,
    required this.hovered,
    required this.moveMode,
    required this.onActivate,
    required this.onFocus,
    required this.onHover,
    this.iconFile,
    this.autofocus = false,
    this.focusNode,
    this.onDragStarted,
    this.onDroppedOn,
  });

  final AppRecord app;
  final HomeDeckMetrics metrics;
  final bool focused;
  final bool hovered;
  final bool moveMode;
  final bool autofocus;
  final FocusNode? focusNode;
  final File? iconFile;
  final VoidCallback onActivate;
  final VoidCallback onFocus;
  final ValueChanged<bool> onHover;
  final VoidCallback? onDragStarted;
  final ValueChanged<String>? onDroppedOn;

  @override
  Widget build(BuildContext context) {
    final visual = GlossyTileFrame(
      metrics: metrics,
      focused: focused,
      hovered: hovered,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _InitialFace(name: app.displayName, color: colorForKey(app.id)),
          if (iconFile != null)
            Image.file(
              iconFile!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, sync) {
                if (frame == null && !sync) {
                  return const SizedBox.shrink();
                }
                return child;
              },
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          if (app.favorite)
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.star_rounded, color: HomeDeckColors.gold, size: 22),
            ),
          if (moveMode && focused)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HomeDeckColors.cyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'MOVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11 * metrics.scale,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (hasFocus) {
        if (hasFocus && !focused) {
          onFocus();
        }
      },
      child: Builder(
        builder: (context) {
          return MouseRegion(
            onEnter: (_) => onHover(true),
            onExit: (_) => onHover(false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Focus.of(context).requestFocus();
                onFocus();
                onActivate();
              },
              child: TileCell(
                metrics: metrics,
                label: app.displayName,
                labelColor: focused ? HomeDeckColors.cyanDeep : HomeDeckColors.ink,
                tile: LongPressDraggable<String>(
                  data: app.id,
                  onDragStarted: onDragStarted,
                  feedback: Opacity(
                    opacity: 0.9,
                    child: SizedBox(width: 160, height: 160, child: visual),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: visual),
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (details) => details.data != app.id,
                    onAcceptWithDetails: (details) =>
                        onDroppedOn?.call(details.data),
                    builder: (context, _, _) => visual,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AddTile extends StatelessWidget {
  const AddTile({
    super.key,
    required this.metrics,
    required this.focused,
    required this.hovered,
    required this.onActivate,
    required this.onFocus,
    required this.onHover,
    this.autofocus = false,
    this.focusNode,
  });

  final HomeDeckMetrics metrics;
  final bool focused;
  final bool hovered;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback onActivate;
  final VoidCallback onFocus;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (hasFocus) {
        if (hasFocus && !focused) {
          onFocus();
        }
      },
      child: Builder(
        builder: (context) {
          return MouseRegion(
            onEnter: (_) => onHover(true),
            onExit: (_) => onHover(false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Focus.of(context).requestFocus();
                onFocus();
                onActivate();
              },
              child: TileCell(
                metrics: metrics,
                label: 'Add app',
                labelColor: focused
                    ? HomeDeckColors.cyanDeep
                    : HomeDeckColors.muted,
                tile: GlossyTileFrame(
                  metrics: metrics,
                  focused: focused,
                  hovered: hovered,
                  child: ColoredBox(
                    color: const Color(0xFFF0F3F7),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 42 * metrics.scale,
                              color: HomeDeckColors.cyanDeep,
                            ),
                            Text(
                              'Add',
                              style: TextStyle(
                                color: HomeDeckColors.ink,
                                fontSize: 16 * metrics.scale,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmptySlot extends StatelessWidget {
  const EmptySlot({super.key, required this.metrics});

  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return TileCell(
      metrics: metrics,
      tile: DecoratedBox(
        decoration: BoxDecoration(
          color: HomeDeckColors.tileEmpty.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18 * metrics.scale),
          border: Border.all(color: HomeDeckColors.tileEmptyEdge, width: 2),
        ),
      ),
    );
  }
}

/// Square tile plus an optional caption, sized to the cell so rows never overflow.
class TileCell extends StatelessWidget {
  const TileCell({
    super.key,
    required this.metrics,
    required this.tile,
    this.label,
    this.labelColor,
  });

  final HomeDeckMetrics metrics;
  final Widget tile;
  final String? label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 6 * metrics.scale;
        final labelH = label == null ? 0.0 : metrics.tileNameSize * 1.1;
        final reserved = gap + labelH + 2;
        final side = math.min(
          constraints.maxWidth,
          math.max(0.0, constraints.maxHeight - reserved),
        );
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: side,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: side, height: side, child: tile),
                if (label != null) ...[
                  SizedBox(height: gap),
                  Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    strutStyle: StrutStyle(
                      fontSize: metrics.tileNameSize,
                      height: 1.1,
                      forceStrutHeight: true,
                    ),
                    style: TextStyle(
                      color: labelColor ?? HomeDeckColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: metrics.tileNameSize,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// White bezel, soft shadow, top gloss, cyan selection glow.
class GlossyTileFrame extends StatelessWidget {
  const GlossyTileFrame({
    super.key,
    required this.metrics,
    required this.focused,
    required this.hovered,
    required this.child,
  });

  final HomeDeckMetrics metrics;
  final bool focused;
  final bool hovered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = focused ? 1.07 : (hovered ? 1.03 : 1.0);
    final radius = 18 * metrics.scale;
    return AnimatedScale(
      scale: scale,
      alignment: Alignment.center,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.all(focused ? 5 : 4),
        decoration: BoxDecoration(
          color: HomeDeckColors.tileFrame,
          borderRadius: BorderRadius.circular(radius + 4),
          border: Border.all(
            color: focused ? HomeDeckColors.cyan : const Color(0xFFE4E8EE),
            width: focused ? 5 : 1.5,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF3F5F8)],
          ),
          boxShadow: [
            BoxShadow(
              color: focused
                  ? HomeDeckColors.cyan.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.18),
              blurRadius: focused ? 22 : 10,
              spreadRadius: focused ? 1 : 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialFace extends StatelessWidget {
  const _InitialFace({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            initialFor(name),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 56,
            ),
          ),
        ),
      ),
    );
  }
}
