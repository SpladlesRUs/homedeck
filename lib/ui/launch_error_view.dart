import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

class LaunchErrorView extends StatelessWidget {
  const LaunchErrorView({
    super.key,
    required this.failure,
    required this.appName,
    required this.scale,
    required this.onDismiss,
  });

  final LaunchFailure failure;
  final String appName;
  final double scale;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        DismissOverlayIntent: CallbackAction<DismissOverlayIntent>(
          onInvoke: (_) {
            onDismiss();
            return null;
          },
        ),
        ConfirmIntent: CallbackAction<ConfirmIntent>(
          onInvoke: (_) {
            onDismiss();
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Material(
            color: Colors.black.withValues(alpha: 0.72),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 760 * scale.clamp(0.8, 1.4),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: HomeDeckColors.deepIndigo,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: HomeDeckColors.danger,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: HomeDeckColors.danger.withValues(alpha: 0.35),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(36 * scale),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: HomeDeckColors.danger,
                            size: 72 * scale,
                          ),
                          SizedBox(height: 16 * scale),
                          Text(
                            "CAN'T LAUNCH",
                            key: const Key('launch-error-title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: HomeDeckColors.danger,
                              fontWeight: FontWeight.w900,
                              fontSize: 28 * scale,
                              letterSpacing: 2.4,
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          Text(
                            appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: HomeDeckColors.goldBright,
                              fontWeight: FontWeight.w800,
                              fontSize: 32 * scale,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          Text(
                            failure.message,
                            key: const Key('launch-error-message'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: HomeDeckColors.cream,
                              fontWeight: FontWeight.w600,
                              fontSize: 26 * scale,
                              height: 1.25,
                            ),
                          ),
                          if (failure.detail != null) ...[
                            SizedBox(height: 12 * scale),
                            Text(
                              failure.detail!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16 * scale,
                              ),
                            ),
                          ],
                          SizedBox(height: 28 * scale),
                          FilledButton(
                            key: const Key('launch-error-ok'),
                            onPressed: onDismiss,
                            style: FilledButton.styleFrom(
                              backgroundColor: HomeDeckColors.gold,
                              foregroundColor: HomeDeckColors.voidNavy,
                              padding: EdgeInsets.symmetric(
                                horizontal: 36 * scale,
                                vertical: 16 * scale,
                              ),
                              textStyle: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22 * scale,
                              ),
                            ),
                            child: const Text('OK'),
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
      ),
    );
  }
}
