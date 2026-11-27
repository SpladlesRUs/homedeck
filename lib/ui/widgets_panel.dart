import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

/// Empty-state copy for the Widgets slide-over (Ally UIA / M30 pattern).
const String kWidgetsEmptyCopy = 'No widgets yet';

/// Lightweight Widgets panel (iiSU Customize Home chrome). Empty stub only —
/// no music/theme packs, no scrape, no widget catalog this milestone.
class WidgetsPanel extends StatelessWidget {
  const WidgetsPanel({
    super.key,
    required this.scale,
    required this.onClose,
  });

  final double scale;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        DismissOverlayIntent: CallbackAction<DismissOverlayIntent>(
          onInvoke: (_) {
            onClose();
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420 * scale,
                minWidth: 320 * scale,
              ),
              child: Material(
                key: const Key('widgets-panel'),
                color: const Color(0xFF1B2433),
                elevation: 8,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(24),
                  ),
                  side: BorderSide(color: HomeDeckColors.cyan, width: 2),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      22 * scale,
                      20 * scale,
                      22 * scale,
                      18 * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Widgets',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22 * scale,
                                ),
                              ),
                            ),
                            Semantics(
                              key: const Key('widgets-close'),
                              button: true,
                              label: 'Close widgets',
                              onTap: onClose,
                              child: GestureDetector(
                                onTap: onClose,
                                child: Text(
                                  'Close · B',
                                  style: TextStyle(
                                    color: HomeDeckColors.muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13 * scale,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16 * scale),
                        Expanded(
                          child: Center(
                            child: Semantics(
                              key: const Key('widgets-empty'),
                              container: true,
                              label: kWidgetsEmptyCopy,
                              excludeSemantics: true,
                              child: Text(
                                kWidgetsEmptyCopy,
                                style: TextStyle(
                                  color: HomeDeckColors.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15 * scale,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
