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
    this.onRecents,
    this.onScanSteam,
    this.onScanStartMenu,
    this.onScanRoms,
    this.onScanEpic,
    this.onScanGog,
    this.onScanUbisoft,
    this.onScanEa,
    this.onScanBattlenet,
    this.onScanXbox,
    this.onReorder,
    this.onRefreshHome,
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
  /// Same path as bare **D** / `_openRecents` (closes menu first).
  final VoidCallback? onRecents;
  /// Library-only: same import path as Settings / harness **S**.
  final VoidCallback? onScanSteam;
  /// Library-only: same import path as Settings / harness **P**.
  final VoidCallback? onScanStartMenu;
  /// Library-only: same import path as Settings / harness **R**.
  final VoidCallback? onScanRoms;
  /// Library-only: same import path as Settings / harness **E**.
  final VoidCallback? onScanEpic;
  /// Library-only: same import path as Settings / harness **G**.
  final VoidCallback? onScanGog;
  /// Library-only: same import path as Settings / harness **U**.
  final VoidCallback? onScanUbisoft;
  /// Library-only: same import path as Settings / harness **O**.
  final VoidCallback? onScanEa;
  /// Library-only: same import path as Settings / harness **N**.
  final VoidCallback? onScanBattlenet;
  /// Library-only: same import path as Settings / harness **W**.
  final VoidCallback? onScanXbox;
  final VoidCallback? onReorder;
  /// Home-only: jump to page 0 and clear move-mode (iiSU Customize Home).
  final VoidCallback? onRefreshHome;
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                    ),
                    child: SingleChildScrollView(
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
                          if (onRecents != null)
                            _row(
                              key: const Key('menu-recents'),
                              label: 'Recents',
                              onTap: onRecents!,
                            ),
                          if (onReorder != null)
                            _row(
                              key: const Key('menu-reorder'),
                              label: 'Reorder home',
                              onTap: onReorder!,
                            ),
                          if (onRefreshHome != null)
                            _row(
                              key: const Key('menu-refresh-home'),
                              label: 'Refresh Home',
                              onTap: onRefreshHome!,
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
                          // Library rescans after tile actions so Add to Home /
                          // Details stay on-screen when many storefront rows
                          // force the menu to scroll.
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
                          if (onScanEpic != null)
                            _row(
                              key: const Key('menu-scan-epic'),
                              label: 'Rescan Epic Games',
                              onTap: onScanEpic!,
                            ),
                          if (onScanGog != null)
                            _row(
                              key: const Key('menu-scan-gog'),
                              label: 'Rescan GOG',
                              onTap: onScanGog!,
                            ),
                          if (onScanUbisoft != null)
                            _row(
                              key: const Key('menu-scan-ubisoft'),
                              label: 'Rescan Ubisoft Connect',
                              onTap: onScanUbisoft!,
                            ),
                          if (onScanEa != null)
                            _row(
                              key: const Key('menu-scan-ea'),
                              label: 'Rescan EA App',
                              onTap: onScanEa!,
                            ),
                          if (onScanBattlenet != null)
                            _row(
                              key: const Key('menu-scan-battlenet'),
                              label: 'Rescan Battle.net',
                              onTap: onScanBattlenet!,
                            ),
                          if (onScanXbox != null)
                            _row(
                              key: const Key('menu-scan-xbox'),
                              label: 'Rescan Xbox / Microsoft Store',
                              onTap: onScanXbox!,
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
