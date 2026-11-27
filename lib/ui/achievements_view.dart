import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

/// Dock Achievements tab empty chrome (iiSU Trophies parity — no RetroAchievements
/// login, scrape, or per-game cards this milestone).
class AchievementsView extends StatelessWidget {
  const AchievementsView({super.key, required this.metrics});

  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('achievements-tab'),
      label: 'Achievements',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: HomeDeckColors.muted,
              size: 48 * metrics.scale,
            ),
            SizedBox(height: 12 * metrics.scale),
            Text(
              'Achievements',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22 * metrics.scale,
              ),
            ),
            SizedBox(height: 6 * metrics.scale),
            Text(
              key: const Key('achievements-empty'),
              'No achievements yet',
              style: TextStyle(
                color: HomeDeckColors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 14 * metrics.scale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
