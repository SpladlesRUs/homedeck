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
    final visual = TileFace(
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
              top: 6,
              right: 6,
              child: Icon(
                Icons.star_rounded,
                color: HomeDeckColors.gold,
                size: 16,
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
              child: Semantics(
                label: app.displayName,
                button: true,
                child: LongPressDraggable<String>(
                  data: app.id,
                  onDragStarted: onDragStarted,
                  feedback: Opacity(
                    opacity: 0.9,
                    child: SizedBox(width: 96, height: 96, child: visual),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: visual),
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (details) =>
                        details.data != app.id,
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
              child: Semantics(
                label: 'Add app',
                button: true,
                child: TileFace(
                  metrics: metrics,
                  focused: focused,
                  hovered: hovered,
                  child: ColoredBox(
                    color: const Color(0x33263A52),
                    child: Icon(
                      Icons.add_rounded,
                      size: 36 * metrics.scale,
                      color: HomeDeckColors.cyan,
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
  const EmptySlot({
    super.key,
    required this.metrics,
    this.focused = false,
    this.hovered = false,
    this.moveMode = false,
    this.autofocus = false,
    this.focusNode,
    this.onActivate,
    this.onFocus,
    this.onHover,
  });

  final HomeDeckMetrics metrics;
  final bool focused;
  final bool hovered;
  final bool moveMode;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onActivate;
  final VoidCallback? onFocus;
  final ValueChanged<bool>? onHover;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      child: Builder(
        builder: (context) {
          return MouseRegion(
            onEnter: (_) => onHover?.call(true),
            onExit: (_) => onHover?.call(false),
            cursor: onActivate == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Focus.of(context).requestFocus();
                onFocus?.call();
                onActivate?.call();
              },
              child: Semantics(
                label: 'Empty slot',
                button: true,
                child: TileFace(
                  metrics: metrics,
                  focused: focused || moveMode && focused,
                  hovered: hovered,
                  child: ColoredBox(
                    color: HomeDeckColors.tileEmpty,
                    child: moveMode && focused
                        ? Icon(
                            Icons.open_with_rounded,
                            color: HomeDeckColors.cyan,
                            size: 22 * metrics.scale,
                          )
                        : const SizedBox.expand(),
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

class TileFace extends StatefulWidget {
  const TileFace({
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
  State<TileFace> createState() => _TileFaceState();
}

class _TileFaceState extends State<TileFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.focused) {
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(TileFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focused && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.focused && _spin.isAnimating) {
      _spin.stop();
      _spin.reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focused;
    final scale = focused ? 1.08 : (widget.hovered ? 1.03 : 1.0);
    final radius = 14 * widget.metrics.scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: AnimatedBuilder(
              animation: _spin,
              builder: (context, child) {
                return Container(
                  width: side,
                  height: side,
                  padding: EdgeInsets.all(focused ? 3.5 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius + 4),
                    gradient: focused
                        ? SweepGradient(
                            startAngle: _spin.value * 6.2832,
                            colors: const [
                              HomeDeckColors.cyan,
                              HomeDeckColors.purple,
                              HomeDeckColors.cyanDeep,
                              HomeDeckColors.cyan,
                            ],
                          )
                        : null,
                    boxShadow: focused
                        ? [
                            BoxShadow(
                              color: HomeDeckColors.cyan.withValues(
                                alpha: 0.55,
                              ),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: HomeDeckColors.purple.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                            ),
                          ]
                        : const [],
                  ),
                  child: child,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InitialFace extends StatelessWidget {
  const _InitialFace({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            initialFor(name),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 48,
            ),
          ),
        ),
      ),
    );
  }
}
