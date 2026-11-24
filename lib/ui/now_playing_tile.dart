import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

const nowPlayingId = '__homedeck_nowplaying__';

bool isNowPlayingId(String id) => id == nowPlayingId;

class NowPlayingTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final title = music?.currentTitle ?? 'Menu music';
    final playing = music?.isPlaying ?? false;
    final enabled = music?.musicEnabled ?? false;
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocus();
        }
      },
      child: GestureDetector(
        onTap: () {
          focusNode.requestFocus();
          onFocus();
          onActivate();
        },
        child: Semantics(
          label: 'Now playing $title',
          button: true,
          child: TileFace(
            metrics: metrics,
            focused: focused,
            hovered: false,
            child: ColoredBox(
              color: const Color(0xFF1A2433),
              child: Stack(
                children: [
                  const Positioned(
                    left: 14,
                    bottom: 14,
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Colors.white70,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(18 * metrics.scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enabled ? 'Now playing' : 'Last played',
                          key: const Key('now-playing-label'),
                          style: TextStyle(
                            color: HomeDeckColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13 * metrics.scale,
                          ),
                        ),
                        SizedBox(height: 8 * metrics.scale),
                        Text(
                          title,
                          key: const Key('now-playing-title'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22 * metrics.scale,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            IconButton(
                              key: const Key('now-playing-toggle'),
                              onPressed: () => music?.togglePause(),
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              key: const Key('now-playing-next'),
                              onPressed: () => music?.skipNext(),
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
