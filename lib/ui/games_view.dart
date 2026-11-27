import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

/// Dock Games tab empty chrome (pinned-games surface — not a second Library
/// scanner or grid this milestone).
class GamesView extends StatelessWidget {
  const GamesView({super.key, required this.metrics});

  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    // explicitChildNodes so the empty-copy Semantics label is not swallowed
    // by the tab title merge (Ally UIA needs Name to contain empty copy).
    return Semantics(
      key: const Key('games-tab'),
      label: 'Games',
      explicitChildNodes: true,
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
            Semantics(
              key: const Key('games-empty'),
              label: 'No games yet',
              excludeSemantics: true,
              child: Text(
                'No games yet',
                style: TextStyle(
                  color: HomeDeckColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * metrics.scale,
                ),
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
