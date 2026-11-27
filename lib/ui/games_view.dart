import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

/// Dock Games tab empty chrome (pinned-games surface — not a second Library
/// scanner or grid this milestone).
class GamesView extends StatelessWidget {
  const GamesView({super.key, required this.metrics});

  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('games-tab'),
      label: 'Games',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_esports_rounded,
              color: HomeDeckColors.muted,
              size: 48 * metrics.scale,
            ),
            SizedBox(height: 12 * metrics.scale),
            Text(
              'Games',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22 * metrics.scale,
              ),
            ),
            SizedBox(height: 6 * metrics.scale),
            Text(
              key: const Key('games-empty'),
              'No games yet',
              style: TextStyle(
                color: HomeDeckColors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 14 * metrics.scale,
              ),
            ),
            SizedBox(height: 4 * metrics.scale),
            Text(
              'Pin games from Library',
              style: TextStyle(
                color: HomeDeckColors.muted,
                fontWeight: FontWeight.w500,
                fontSize: 13 * metrics.scale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
