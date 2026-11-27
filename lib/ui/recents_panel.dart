import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

/// Empty-state copy for the Recents / app drawer slide-over.
const String kRecentsEmptyCopy = 'No recent apps';

/// Recents / app-drawer slide-over (iiSU chrome parity). Empty list is OK;
/// no Android / Play Games scrapers — chrome only. Optional recent
/// [AppRecord] titles may be passed when an in-memory list exists.
class RecentsPanel extends StatelessWidget {
  const RecentsPanel({
    super.key,
    required this.scale,
    required this.onClose,
    this.titles = const <String>[],
  });

  final double scale;
  final VoidCallback onClose;
  final List<String> titles;

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
                key: const Key('recents-drawer'),
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
                                'Recents',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22 * scale,
                                ),
                              ),
                            ),
                            Semantics(
                              key: const Key('recents-close'),
                              button: true,
                              label: 'Close recents',
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
                          child: titles.isEmpty
                              ? Center(
                                  child: Semantics(
                                    key: const Key('recents-empty'),
                                    container: true,
                                    label: kRecentsEmptyCopy,
                                    excludeSemantics: true,
                                    child: Text(
                                      kRecentsEmptyCopy,
                                      style: TextStyle(
                                        color: HomeDeckColors.muted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15 * scale,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: titles.length,
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
                                        titles[index],
                                        key: Key('recents-line-$index'),
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
