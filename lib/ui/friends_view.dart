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
    // explicitChildNodes so the empty-copy Semantics label is not swallowed
    // by the tab title merge (Ally UIA needs Name to contain empty copy).
    return Semantics(
      key: const Key('friends-tab'),
      label: 'Friends',
      explicitChildNodes: true,
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
            Semantics(
              key: const Key('friends-empty'),
              label: kFriendsEmptyCopy,
              excludeSemantics: true,
              child: Text(
                kFriendsEmptyCopy,
                style: TextStyle(
                  color: HomeDeckColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * metrics.scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
