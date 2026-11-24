import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

/// Hook for Tre's original per-console PNGs. Returns null until those land.
String? platformIconAsset(String slug) {
  // Reserved path: assets/branding/platforms/$slug.png
  return null;
}

class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.title,
    required this.slug,
    required this.count,
    required this.metrics,
    required this.focused,
    required this.focusNode,
    required this.onFocus,
    required this.onHover,
    required this.onOpen,
  });

  final String title;
  final String slug;
  final int count;
  final HomeDeckMetrics metrics;
  final bool focused;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final ValueChanged<bool> onHover;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = colorForKey(slug);
    final asset = platformIconAsset(slug);
    final captionSize = 12 * metrics.scale;
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocus();
        }
      },
      child: MouseRegion(
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: () {
            focusNode.requestFocus();
            onFocus();
            onOpen();
          },
          child: Semantics(
            label: title,
            button: true,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(10 * metrics.scale),
                    child: TileFace(
                      metrics: metrics,
                      focused: focused,
                      hovered: false,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color,
                                  Color.lerp(color, Colors.black, 0.35)!,
                                ],
                              ),
                            ),
                          ),
                          if (asset != null)
                            Image.asset(asset, fit: BoxFit.cover)
                          else
                            Center(
                              child: Text(
                                title.isEmpty ? '?' : title[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 32 * metrics.scale,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 36 * metrics.scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: captionSize,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          '$count',
                          style: TextStyle(
                            color: HomeDeckColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 11 * metrics.scale,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
