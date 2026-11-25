import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

/// Settings: window chrome, audio, Steam / Start Menu scan, open questions.
class SettingsStub extends StatelessWidget {
  const SettingsStub({
    super.key,
    required this.windowMode,
    required this.scale,
    required this.onClose,
    required this.onToggleFullscreen,
    required this.onToggleBorderless,
    this.musicEnabled = true,
    this.musicVolume = 0.35,
    this.uiClicksEnabled = true,
    this.onMusicEnabled,
    this.onMusicVolume,
    this.onUiClicksEnabled,
    this.onScanSteam,
    this.steamScanBusy = false,
    this.steamScanMessage,
    this.onScanStartMenu,
    this.startMenuScanBusy = false,
    this.startMenuScanMessage,
    this.onExit,
  });

  final WindowModeController windowMode;
  final double scale;
  final VoidCallback onClose;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleBorderless;
  final bool musicEnabled;
  final double musicVolume;
  final bool uiClicksEnabled;
  final ValueChanged<bool>? onMusicEnabled;
  final ValueChanged<double>? onMusicVolume;
  final ValueChanged<bool>? onUiClicksEnabled;
  final VoidCallback? onScanSteam;
  final bool steamScanBusy;
  final String? steamScanMessage;
  final VoidCallback? onScanStartMenu;
  final bool startMenuScanBusy;
  final String? startMenuScanMessage;
  final VoidCallback? onExit;

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
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: const BorderSide(color: HomeDeckColors.cyan, width: 3),
                ),
                child: Padding(
                  padding: EdgeInsets.all(32 * scale.clamp(0.8, 1.3)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.86,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const HomeDeckMark(size: 56),
                              const SizedBox(width: 12),
                              Text(
                                'Settings',
                                style: TextStyle(
                                  color: HomeDeckColors.ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 32 * scale,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: onClose,
                                icon: const Icon(
                                  Icons.close,
                                  color: HomeDeckColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _ToggleRow(
                            label: 'Fullscreen',
                            hint: 'F11',
                            value: windowMode.isFullscreen,
                            onChanged: (_) => onToggleFullscreen(),
                          ),
                          _ToggleRow(
                            label: 'Borderless',
                            hint: 'Hide the window frame',
                            value: windowMode.isBorderless,
                            onChanged: (_) => onToggleBorderless(),
                          ),
                          _ToggleRow(
                            key: const Key('settings-music-enabled'),
                            label: 'Menu music',
                            hint: 'Playlist of ten instrumentals',
                            value: musicEnabled,
                            onChanged: onMusicEnabled ?? (_) {},
                          ),
                          _ToggleRow(
                            key: const Key('settings-ui-clicks'),
                            label: 'UI clicks',
                            hint: 'Short ticks on move, select, back, and page',
                            value: uiClicksEnabled,
                            onChanged: onUiClicksEnabled ?? (_) {},
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              right: 4,
                              bottom: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Volume',
                                  style: TextStyle(
                                    color: HomeDeckColors.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                Slider(
                                  key: const Key('settings-music-volume'),
                                  value: musicVolume.clamp(0.0, 1.0),
                                  onChanged: musicEnabled
                                      ? onMusicVolume
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Steam library',
                            style: TextStyle(
                              color: HomeDeckColors.cyanDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 18 * scale,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan installs Steam games into Library (By app → Steam). Keyboard S (Ally SendKeys s) runs the same scan without opening Settings. Manual Add stays available for .exe, .lnk, URIs, and emulators.',
                            style: TextStyle(
                              color: HomeDeckColors.ink,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          if (onScanSteam != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                key: const Key('settings-scan-steam'),
                                onPressed: steamScanBusy ? null : onScanSteam,
                                child: Text(
                                  steamScanBusy
                                      ? 'Scanning…'
                                      : 'Scan Steam library',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (steamScanMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              steamScanMessage!,
                              key: const Key('settings-scan-steam-message'),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Start Menu',
                            style: TextStyle(
                              color: HomeDeckColors.cyanDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 18 * scale,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan imports Start Menu Programs shortcuts into Library (By app → Other / matching store). Keyboard P (Ally SendKeys p) runs the same scan without opening Settings. Manual Add and Steam Scan (S) stay unchanged.',
                            style: TextStyle(
                              color: HomeDeckColors.ink,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          if (onScanStartMenu != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                key: const Key('settings-scan-start-menu'),
                                onPressed:
                                    startMenuScanBusy ? null : onScanStartMenu,
                                child: Text(
                                  startMenuScanBusy
                                      ? 'Scanning…'
                                      : 'Scan Start Menu',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (startMenuScanMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              startMenuScanMessage!,
                              key: const Key(
                                'settings-scan-start-menu-message',
                              ),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            'The library can hold games, emulators, and general applications. Scope is still an open product question. ROM-folder discovery is not enabled yet.',
                            style: TextStyle(
                              color: HomeDeckColors.muted,
                              fontSize: 16,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Column(
                              children: [
                                const HomeDeckMark(size: 96),
                                const SizedBox(height: 8),
                                Text(
                                  'HomeDeck',
                                  style: TextStyle(
                                    color: HomeDeckColors.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22 * scale,
                                  ),
                                ),
                                const Text(
                                  'Version 1.0.0',
                                  style: TextStyle(color: HomeDeckColors.muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 12,
                              children: [
                                if (onExit != null)
                                  TextButton(
                                    key: const Key('settings-exit'),
                                    onPressed: onExit,
                                    child: const Text(
                                      'Exit  ·  Power',
                                      style: TextStyle(
                                        color: HomeDeckColors.danger,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: onClose,
                                  child: const Text(
                                    'Close  ·  Esc',
                                    style: TextStyle(
                                      color: HomeDeckColors.cyanDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
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
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          color: HomeDeckColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      subtitle: Text(hint, style: const TextStyle(color: HomeDeckColors.muted)),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: HomeDeckColors.cyan,
      onChanged: onChanged,
    );
  }
}
