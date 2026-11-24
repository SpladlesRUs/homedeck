import 'dart:math' as math;

import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/core/menu_playlist.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

const nowPlayingId = '__homedeck_nowplaying__';

bool isNowPlayingId(String id) => id == nowPlayingId;

class NowPlayingTile extends StatefulWidget {
  const NowPlayingTile({
    super.key,
    required this.metrics,
    required this.music,
    required this.focused,
    required this.focusNode,
    required this.onFocus,
    required this.onActivate,
  });

  final HomeDeckMetrics metrics;
  final MenuMusicController? music;
  final bool focused;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onActivate;

  @override
  State<NowPlayingTile> createState() => _NowPlayingTileState();
}

class _NowPlayingTileState extends State<NowPlayingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = widget.music;
    final title = music?.currentTitle ?? 'Menu music';
    final playing = music?.isPlaying ?? false;
    final enabled = music?.musicEnabled ?? false;
    final index = music?.currentIndex ?? 0;
    final total = MenuPlaylist.tracks.length;
    final n = total == 0 ? 0 : (index % total) + 1;
    final scale = widget.metrics.scale;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          widget.onFocus();
        }
      },
      child: GestureDetector(
        onTap: () {
          widget.focusNode.requestFocus();
          widget.onFocus();
          widget.onActivate();
        },
        child: Semantics(
          label: 'Now playing $title',
          button: true,
          child: TileFace(
            metrics: widget.metrics,
            focused: widget.focused,
            hovered: false,
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + _motion.value * 2, -1),
                          end: Alignment(1 - _motion.value * 2, 1),
                          colors: const [
                            Color(0xFF142033),
                            Color(0xFF1C3A52),
                            Color(0xFF2A2450),
                            Color(0xFF123044),
                          ],
                        ),
                      ),
                    ),
                    CustomPaint(painter: _MenuWavePainter(t: _motion.value)),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        22 * scale,
                        20 * scale,
                        22 * scale,
                        16 * scale,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                enabled ? 'Now playing' : 'Last played',
                                key: const Key('now-playing-label'),
                                style: TextStyle(
                                  color: HomeDeckColors.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13 * scale,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.music_note_rounded,
                                color: HomeDeckColors.cyan.withValues(
                                  alpha: 0.85,
                                ),
                                size: 22 * scale,
                              ),
                            ],
                          ),
                          SizedBox(height: 12 * scale),
                          Text(
                            title,
                            key: const Key('now-playing-title'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 28 * scale,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            'HomeDeck Menu Music',
                            key: const Key('now-playing-subtitle'),
                            style: TextStyle(
                              color: HomeDeckColors.cyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 14 * scale,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            '$n / $total',
                            key: const Key('now-playing-index'),
                            style: TextStyle(
                              color: HomeDeckColors.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13 * scale,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _ControlButton(
                                key: const Key('now-playing-toggle'),
                                icon: playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 36 * scale,
                                onPressed: () => music?.togglePause(),
                              ),
                              SizedBox(width: 8 * scale),
                              _ControlButton(
                                key: const Key('now-playing-next'),
                                icon: Icons.skip_next_rounded,
                                size: 36 * scale,
                                onPressed: () => music?.skipNext(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size + 16,
          height: size + 16,
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

class _MenuWavePainter extends CustomPainter {
  _MenuWavePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final path = Path()..moveTo(0, size.height);
      final base = size.height * (0.42 + i * 0.16);
      final amp = 16.0 + i * 6;
      final phase = t * math.pi * 2 + i * 1.2;
      for (var x = 0.0; x <= size.width; x += 6) {
        final y = base + math.sin((x / size.width) * math.pi * 2 + phase) * amp;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
            HomeDeckColors.cyan,
            HomeDeckColors.purple,
            i / 3,
          )!.withValues(alpha: 0.10 + i * 0.03),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MenuWavePainter oldDelegate) =>
      oldDelegate.t != t;
}
