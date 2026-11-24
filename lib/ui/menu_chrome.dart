import 'dart:io';
import 'dart:ui' as ui;

import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

class ArtBackdrop extends StatelessWidget {
  const ArtBackdrop({
    super.key,
    required this.color,
    this.imageFile,
    this.assetPath,
  });

  final Color color;
  final File? imageFile;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    Widget art;
    if (imageFile != null) {
      art = Image.file(
        imageFile!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => ColoredBox(color: color),
        frameBuilder: (context, child, frame, sync) {
          if (frame == null && !sync) {
            return ColoredBox(color: color);
          }
          return child;
        },
      );
    } else if (assetPath != null) {
      art = Image.asset(assetPath!, fit: BoxFit.cover);
    } else {
      art = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              HomeDeckColors.canvasDeep,
              Color.lerp(color, Colors.black, 0.45)!,
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: HomeDeckColors.canvasDeep),
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 42, sigmaY: 42),
          child: Transform.scale(scale: 1.18, child: art),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x99000000),
                Color(0xCC000000),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HomeDeckColors.glass,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: HomeDeckColors.glassEdge, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }
}

class HintBadge extends StatelessWidget {
  const HintBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xEE1C2836),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class ProfileCluster extends StatelessWidget {
  const ProfileCluster({super.key, required this.metrics, this.extra = 2});

  final HomeDeckMetrics metrics;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final size = 34 * metrics.scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.7,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: size * 0.55,
                child: _AvatarCircle(
                  size: size * 0.9,
                  color: const Color(0xFF5B8DEF),
                  letter: 'K',
                ),
              ),
              Positioned(
                left: 0,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(child: HomeDeckMark(size: size)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8 * metrics.scale),
        Text(
          '+$extra',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13 * metrics.scale,
          ),
        ),
        SizedBox(width: 8 * metrics.scale),
        const HintBadge(label: 'LT'),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.size,
    required this.color,
    required this.letter,
  });

  final double size;
  final Color color;
  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white54, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class TitlePill extends StatelessWidget {
  const TitlePill({super.key, required this.title, required this.metrics});

  final String title;
  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('title-pill'),
      padding: EdgeInsets.symmetric(
        horizontal: 22 * metrics.scale,
        vertical: 8 * metrics.scale,
      ),
      decoration: BoxDecoration(
        color: HomeDeckColors.pill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16 * metrics.scale,
        ),
      ),
    );
  }
}

class StatusCluster extends StatelessWidget {
  const StatusCluster({
    super.key,
    required this.metrics,
    required this.now,
    this.batteryPercent,
    this.fullscreen = false,
  });

  final HomeDeckMetrics metrics;
  final DateTime now;
  final int? batteryPercent;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * metrics.scale,
            vertical: 6 * metrics.scale,
          ),
          decoration: BoxDecoration(
            color: HomeDeckColors.pill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 18 * metrics.scale,
              ),
              SizedBox(width: 10 * metrics.scale),
              Text(
                time,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14 * metrics.scale,
                ),
              ),
              Text(
                '  |  $date',
                style: TextStyle(
                  color: HomeDeckColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * metrics.scale,
                ),
              ),
              if (batteryPercent != null) ...[
                SizedBox(width: 10 * metrics.scale),
                Icon(
                  Icons.battery_full_rounded,
                  color: Colors.white,
                  size: 16 * metrics.scale,
                ),
                SizedBox(width: 2 * metrics.scale),
                Text(
                  '$batteryPercent%',
                  key: const Key('battery-percent'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * metrics.scale,
                  ),
                ),
              ],
              if (fullscreen) ...[
                SizedBox(width: 10 * metrics.scale),
                Text(
                  'FULLSCREEN',
                  key: const Key('fullscreen-badge'),
                  style: TextStyle(
                    color: HomeDeckColors.cyan,
                    fontWeight: FontWeight.w800,
                    fontSize: 11 * metrics.scale,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 8 * metrics.scale),
        const HintBadge(label: 'RT'),
        SizedBox(width: 8 * metrics.scale),
        Container(
          width: 32 * metrics.scale,
          height: 32 * metrics.scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: HomeDeckMark(size: 32 * metrics.scale),
          ),
        ),
      ],
    );
  }
}

class TabDock extends StatelessWidget {
  const TabDock({
    super.key,
    required this.metrics,
    required this.active,
    required this.onSelect,
  });

  final HomeDeckMetrics metrics;
  final HomeTab active;
  final ValueChanged<HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <(HomeTab, IconData, String)>[
      (HomeTab.home, Icons.home_rounded, 'Home'),
      (HomeTab.games, Icons.sports_esports_rounded, 'Games'),
      (HomeTab.achievements, Icons.emoji_events_rounded, 'Achievements'),
      (HomeTab.friends, Icons.sentiment_satisfied_alt_rounded, 'Friends'),
      (HomeTab.allApps, Icons.apps_rounded, 'All apps'),
    ];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * metrics.scale,
        vertical: 8 * metrics.scale,
      ),
      decoration: BoxDecoration(
        color: HomeDeckColors.dockFill,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HintBadge(label: 'LB'),
          SizedBox(width: 10 * metrics.scale),
          for (final item in items)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * metrics.scale),
              child: GestureDetector(
                key: Key('tab-${item.$1.name}'),
                onTap: () => onSelect(item.$1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.$2,
                      color: active == item.$1
                          ? Colors.white
                          : HomeDeckColors.muted,
                      size: metrics.dockSize * 0.62,
                    ),
                    SizedBox(height: 4 * metrics.scale),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: active == item.$1 ? 18 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: HomeDeckColors.cyan,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(width: 10 * metrics.scale),
          const HintBadge(label: 'RB'),
        ],
      ),
    );
  }
}

class CornerHints extends StatelessWidget {
  const CornerHints({
    super.key,
    required this.metrics,
    required this.onBack,
    required this.onDetails,
    required this.onSelect,
    required this.onMenu,
  });

  final HomeDeckMetrics metrics;
  final VoidCallback onBack;
  final VoidCallback onDetails;
  final VoidCallback onSelect;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 13 * metrics.scale,
    );
    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18 * metrics.scale,
              0,
              0,
              14 * metrics.scale,
            ),
            child: _HintPill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Text('(B) Back', style: style),
                  ),
                  SizedBox(width: 14 * metrics.scale),
                  GestureDetector(
                    onTap: onDetails,
                    child: Text('(-) Details', style: style),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              18 * metrics.scale,
              14 * metrics.scale,
            ),
            child: _HintPill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onSelect,
                    child: Text('(A) Select', style: style),
                  ),
                  SizedBox(width: 14 * metrics.scale),
                  GestureDetector(
                    onTap: onMenu,
                    child: Text('(+) Menu', style: style),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class SubtlePageDots extends StatelessWidget {
  const SubtlePageDots({
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
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            key: ValueKey('page-dot-$i'),
            onTap: () => onSelect(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == page ? 8 : 6,
              height: i == page ? 8 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == page ? Colors.white : const Color(0x66FFFFFF),
              ),
            ),
          ),
      ],
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.title, required this.metrics});

  final String title;
  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            color: HomeDeckColors.muted,
            size: 48 * metrics.scale,
          ),
          SizedBox(height: 12 * metrics.scale),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22 * metrics.scale,
            ),
          ),
          SizedBox(height: 6 * metrics.scale),
          Text(
            'Placeholder in milestone 1',
            style: TextStyle(
              color: HomeDeckColors.muted,
              fontSize: 14 * metrics.scale,
            ),
          ),
        ],
      ),
    );
  }
}

Color backdropColorFor(String? id) {
  if (id == null) {
    return HomeDeckColors.canvas;
  }
  return colorForKey(id);
}
