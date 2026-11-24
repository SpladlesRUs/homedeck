import 'dart:math' as math;

import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:material_ui/material_ui.dart';

class MenuBackdrop extends StatelessWidget {
  const MenuBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFBFCFD),
            HomeDeckColors.canvas,
            HomeDeckColors.canvasDeep,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _RingPatternPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _RingPatternPainter extends CustomPainter {
  const _RingPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = HomeDeckColors.pattern.withValues(alpha: 0.28);
    final center = Offset(size.width / 2, size.height * 0.42);
    final maxR = math.max(size.width, size.height) * 0.72;
    for (var r = 70.0; r < maxR; r += 58) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProfileBadge extends StatelessWidget {
  const ProfileBadge({super.key, required this.metrics});

  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final size = 52 * metrics.scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(3 * metrics.scale),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE0E5EC), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: HomeDeckMark(size: size - 6 * metrics.scale),
          ),
        ),
        SizedBox(width: 10 * metrics.scale),
        Text(
          'HomeDeck',
          style: TextStyle(
            color: HomeDeckColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: metrics.titleSize,
          ),
        ),
      ],
    );
  }
}

class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.page,
    required this.onSelect,
  });

  final int count;
  final int page;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox(height: 18);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            key: ValueKey('page-dot-$i'),
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: i == page ? 12 : 9,
              height: i == page ? 12 : 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == page
                    ? HomeDeckColors.cyanDeep
                    : const Color(0xFFB7C0CC),
              ),
            ),
          ),
      ],
    );
  }
}

class PageEdgeTab extends StatelessWidget {
  const PageEdgeTab({
    super.key,
    required this.left,
    required this.onPressed,
  });

  final bool left;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        elevation: 4,
        borderRadius: BorderRadius.horizontal(
          left: left ? Radius.zero : const Radius.circular(18),
          right: left ? const Radius.circular(18) : Radius.zero,
        ),
        child: InkWell(
          key: Key(left ? 'page-prev' : 'page-next'),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 88,
            child: Icon(
              left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: HomeDeckColors.ink,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

class BottomDock extends StatelessWidget {
  const BottomDock({
    super.key,
    required this.metrics,
    required this.focusedId,
    required this.fullscreen,
    required this.onFocus,
    required this.onSettings,
    required this.onAdd,
    required this.onFullscreen,
    required this.onLibrary,
    required this.onExit,
    required this.focusNodeFor,
  });

  final HomeDeckMetrics metrics;
  final String? focusedId;
  final bool fullscreen;
  final ValueChanged<String> onFocus;
  final VoidCallback onSettings;
  final VoidCallback onAdd;
  final VoidCallback onFullscreen;
  final VoidCallback onLibrary;
  final VoidCallback onExit;
  final FocusNode Function(String id) focusNodeFor;

  @override
  Widget build(BuildContext context) {
    final items = [
      (dockSettingsId, Icons.settings_rounded, 'Settings', onSettings),
      (dockAddId, Icons.add_rounded, 'Add', onAdd),
      (
        dockFullscreenId,
        fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
        'Full screen',
        onFullscreen,
      ),
      (dockLibraryId, Icons.apps_rounded, 'Library', onLibrary),
      (dockExitId, Icons.power_settings_new_rounded, 'Exit', onExit),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * metrics.scale),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 18 * metrics.scale,
          vertical: 8 * metrics.scale,
        ),
        decoration: BoxDecoration(
          color: HomeDeckColors.dockFill.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFFE2E7EE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * metrics.scale),
                child: _DockButton(
                  id: item.$1,
                  icon: item.$2,
                  tooltip: item.$3,
                  size: metrics.dockSize,
                  focused: focusedId == item.$1,
                  onFocus: () => onFocus(item.$1),
                  onPressed: item.$4,
                  focusNode: focusNodeFor(item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.id,
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.focused,
    required this.onFocus,
    required this.onPressed,
    required this.focusNode,
  });

  final String id;
  final IconData icon;
  final String tooltip;
  final double size;
  final bool focused;
  final VoidCallback onFocus;
  final VoidCallback onPressed;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (has) {
        if (has) {
          onFocus();
        }
      },
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          key: Key('dock-$id'),
          onTap: () {
            onFocus();
            onPressed();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: focused ? HomeDeckColors.cyan : const Color(0xFFE4E8EE),
                width: focused ? 4 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: focused
                      ? HomeDeckColors.cyan.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: focused ? 14 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFEEF1F5)],
              ),
            ),
            child: Icon(icon, color: HomeDeckColors.ink, size: size * 0.48),
          ),
        ),
      ),
    );
  }
}
