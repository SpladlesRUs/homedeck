import 'dart:io';

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
    final scale = focused ? 1.08 : (hovered ? 1.03 : 1.0);
    final color = colorForKey(app.id);

    final visual = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22 * metrics.scale),
          boxShadow: [
            BoxShadow(
              color: focused
                  ? HomeDeckColors.gold.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.45),
              blurRadius: focused ? 28 : 16,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: focused ? HomeDeckColors.gold : Colors.white24,
            width: focused ? 6 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1.15,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: color),
              if (iconFile != null)
                Image.file(
                  iconFile!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _InitialFace(
                    name: app.displayName,
                    color: color,
                  ),
                )
              else
                _InitialFace(name: app.displayName, color: color),
              if (app.favorite)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(Icons.star_rounded, color: HomeDeckColors.gold),
                ),
              if (moveMode && focused)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: HomeDeckColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'MOVE',
                      style: TextStyle(
                        color: HomeDeckColors.voidNavy,
                        fontWeight: FontWeight.w800,
                        fontSize: 14 * metrics.scale,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final interactive = Builder(
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
            child: visual,
          ),
        );
      },
    );

    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (hasFocus) {
        if (hasFocus && !focused) {
          onFocus();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LongPressDraggable<String>(
            data: app.id,
            onDragStarted: onDragStarted,
            feedback: Opacity(
              opacity: 0.9,
              child: SizedBox(width: 180, child: visual),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: interactive),
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data != app.id,
              onAcceptWithDetails: (details) => onDroppedOn?.call(details.data),
              builder: (context, _, _) => interactive,
            ),
          ),
          SizedBox(height: 10 * metrics.scale),
          Text(
            app.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: focused ? HomeDeckColors.goldBright : HomeDeckColors.cream,
              fontWeight: FontWeight.w700,
              fontSize: metrics.tileNameSize,
              height: 1.15,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
          ),
        ],
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
    required     this.onHover,
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
    final scale = focused ? 1.08 : (hovered ? 1.03 : 1.0);
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: scale,
                    duration: const Duration(milliseconds: 140),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22 * metrics.scale),
                        color: HomeDeckColors.panel,
                        border: Border.all(
                          color: focused
                              ? HomeDeckColors.gold
                              : HomeDeckColors.muted,
                          width: focused ? 6 : 3,
                        ),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.15,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 64 * metrics.scale,
                              color: HomeDeckColors.gold,
                            ),
                            Text(
                              'Add',
                              style: TextStyle(
                                color: HomeDeckColors.cream,
                                fontSize: 22 * metrics.scale,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10 * metrics.scale),
                  Text(
                    'Add app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: focused
                          ? HomeDeckColors.goldBright
                          : HomeDeckColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: metrics.tileNameSize,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
      child: Center(
        child: Text(
          initialFor(name),
          style: const TextStyle(
            color: HomeDeckColors.cream,
            fontWeight: FontWeight.w800,
            fontSize: 72,
          ),
        ),
      ),
    );
  }
}
