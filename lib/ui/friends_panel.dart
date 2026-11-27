import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

/// LT-style Friends slide-over (iiSU chrome parity). Empty / stub list is OK;
/// no Discord, OAuth, or real presence APIs — chrome only.
class FriendsPanel extends StatelessWidget {
  const FriendsPanel({
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
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420 * scale,
                minWidth: 320 * scale,
              ),
              child: Material(
                key: const Key('friends-panel'),
                color: const Color(0xFF1B2433),
                elevation: 8,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(24),
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
                                'Friends',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22 * scale,
                                ),
                              ),
                            ),
                            Semantics(
                              key: const Key('friends-close'),
                              button: true,
                              label: 'Close friends',
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
                        SizedBox(height: 8 * scale),
                        Text(
                          '0 pinned',
                          style: TextStyle(
                            color: HomeDeckColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13 * scale,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Expanded(
                          child: Center(
                            child: Text(
                              'No friends online',
                              style: TextStyle(
                                color: HomeDeckColors.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 15 * scale,
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
