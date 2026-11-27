import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

/// RT-style Notifications slide-over (iiSU chrome parity). Empty list is OK;
/// optional in-app scan/status lines are passed in — no invented scrape jobs.
class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({
    super.key,
    required this.scale,
    required this.lines,
    required this.onClear,
    required this.onClose,
  });

  final double scale;
  final List<String> lines;
  final VoidCallback onClear;
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
                key: const Key('notifications-panel'),
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
                                'Notifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22 * scale,
                                ),
                              ),
                            ),
                            Semantics(
                              key: const Key('notifications-close'),
                              button: true,
                              label: 'Close notifications',
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
                          child: lines.isEmpty
                              ? Center(
                                  child: Text(
                                    'No notifications',
                                    style: TextStyle(
                                      color: HomeDeckColors.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15 * scale,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: lines.length,
                                  separatorBuilder: (_, _) => Divider(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12 * scale,
                                      ),
                                      child: Text(
                                        lines[index],
                                        key: Key('notification-line-$index'),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14 * scale,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        SizedBox(height: 12 * scale),
                        Semantics(
                          key: const Key('notifications-clear'),
                          button: true,
                          label: 'Clear notifications',
                          onTap: onClear,
                          child: GestureDetector(
                            onTap: onClear,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 12 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x3322D3EE),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: HomeDeckColors.cyan.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Clear notifications',
                                style: TextStyle(
                                  color: HomeDeckColors.cyan,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14 * scale,
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
