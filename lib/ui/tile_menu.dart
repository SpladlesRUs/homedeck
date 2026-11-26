import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

class TileMenu extends StatelessWidget {
  const TileMenu({
    super.key,
    required this.scale,
    required this.onClose,
    required this.onAddGame,
    required this.onSettings,
    required this.onExit,
    this.title,
    this.app,
    this.onHome = false,
    this.pinned = false,
    this.onSearch,
    this.onScanSteam,
    this.onScanStartMenu,
    this.onScanRoms,
    this.onReorder,
    this.onNewPage,
    this.onAddToHome,
    this.onRemoveFromHome,
    this.onMove,
    this.onDetails,
    this.onRemoveFromLibrary,
  });

  final double scale;
  final String? title;
  final AppRecord? app;
  final bool onHome;
  final bool pinned;
  final VoidCallback onClose;
  final VoidCallback onAddGame;
  final VoidCallback onSettings;
  final VoidCallback onExit;
  final VoidCallback? onSearch;
  /// Library-only: same import path as Settings / harness **S**.
  final VoidCallback? onScanSteam;
  /// Library-only: same import path as Settings / harness **P**.
  final VoidCallback? onScanStartMenu;
  /// Library-only: same import path as Settings / harness **R**.
  final VoidCallback? onScanRoms;
  final VoidCallback? onReorder;
  final VoidCallback? onNewPage;
  final VoidCallback? onAddToHome;
  final VoidCallback? onRemoveFromHome;
  final VoidCallback? onMove;
  final VoidCallback? onDetails;
  final VoidCallback? onRemoveFromLibrary;

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                key: const Key('tile-menu'),
                color: const Color(0xFF1B2433),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: HomeDeckColors.cyan, width: 2),
                ),
                child: Padding(
                  padding: EdgeInsets.all(22 * scale),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title ?? app?.displayName ?? 'Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22 * scale,
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      _row(
                        key: const Key('menu-add-game'),
                        label: 'Add game',
                        onTap: onAddGame,
                      ),
                      if (onSearch != null)
                        _row(
                          key: const Key('menu-search'),
                          label: 'Global Search',
                          onTap: onSearch!,
                        ),
                      if (onScanSteam != null)
                        _row(
                          key: const Key('menu-scan-steam'),
                          label: 'Rescan Steam',
                          onTap: onScanSteam!,
                        ),
                      if (onScanStartMenu != null)
                        _row(
                          key: const Key('menu-scan-start-menu'),
                          label: 'Rescan Start Menu',
                          onTap: onScanStartMenu!,
                        ),
                      if (onScanRoms != null)
                        _row(
                          key: const Key('menu-scan-roms'),
                          label: 'Rescan ROM folder',
                          onTap: onScanRoms!,
                        ),
                      if (onReorder != null)
                        _row(
                          key: const Key('menu-reorder'),
                          label: 'Reorder home',
                          onTap: onReorder!,
                        ),
                      if (onNewPage != null)
                        _row(
                          key: const Key('menu-new-page'),
                          label: 'New Collection',
                          onTap: onNewPage!,
                        ),
                      if (app != null && !pinned && onAddToHome != null)
                        _row(
                          key: const Key('menu-add-to-home'),
                          label: 'Add to Home',
                          onTap: onAddToHome!,
                        ),
                      if (app != null && pinned && onRemoveFromHome != null)
                        _row(
                          key: const Key('menu-remove-from-home'),
                          label: 'Remove from Home',
                          onTap: onRemoveFromHome!,
                        ),
                      if (onHome && app != null && onMove != null)
                        _row(
                          key: const Key('menu-move'),
                          label: 'Move',
                          onTap: onMove!,
                        ),
                      if (app != null && onDetails != null)
                        _row(
                          key: const Key('menu-details'),
                          label: 'Details',
                          onTap: onDetails!,
                        ),
                      if (onRemoveFromLibrary != null)
                        _row(
                          key: const Key('menu-remove-library'),
                          label: 'Remove from Library',
                          onTap: onRemoveFromLibrary!,
                        ),
                      _row(
                        key: const Key('menu-settings'),
                        label: 'Settings',
                        onTap: onSettings,
                      ),
                      _row(
                        key: const Key('settings-exit'),
                        label: 'Exit  ·  Power',
                        onTap: onExit,
                        danger: true,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onClose,
                          child: const Text('Close  ·  B'),
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
    );
  }

  Widget _row({
    required Key key,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return ListTile(
      key: key,
      title: Text(
        label,
        style: TextStyle(
          color: danger ? HomeDeckColors.danger : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }
}
