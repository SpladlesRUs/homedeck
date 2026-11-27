import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/friends_panel.dart';
import 'package:material_ui/material_ui.dart';

/// Dock Friends tab empty chrome (separate from the F / LT slide-over panel).
/// No Discord, OAuth, or real presence APIs — chrome only this milestone.
class FriendsView extends StatelessWidget {
  const FriendsView({super.key, required this.metrics});

  final HomeDeckMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('friends-tab'),
      label: 'Friends',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_satisfied_alt_rounded,
              color: HomeDeckColors.muted,
              size: 48 * metrics.scale,
            ),
            SizedBox(height: 12 * metrics.scale),
            Text(
              'Friends',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22 * metrics.scale,
              ),
            ),
            SizedBox(height: 6 * metrics.scale),
            Text(
              key: const Key('friends-empty'),
              kFriendsEmptyCopy,
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
