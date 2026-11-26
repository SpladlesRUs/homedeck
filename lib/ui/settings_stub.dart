import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

/// Settings: window chrome, audio, Steam / Start Menu / ROM / Epic / GOG /
/// Ubisoft / EA scan, open questions.
class SettingsStub extends StatelessWidget {
  const SettingsStub({
    super.key,
    required this.windowMode,
    required this.scale,
    required this.onClose,
    required this.onToggleFullscreen,
    required this.onToggleBorderless,
    this.fullscreenOnLaunch = true,
    this.onFullscreenOnLaunch,
    this.restoreOnExit = true,
    this.onRestoreOnExit,
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
    this.romRoot,
    this.onPickRomRoot,
    this.onScanRoms,
    this.romScanBusy = false,
    this.romScanMessage,
    this.onScanEpic,
    this.epicScanBusy = false,
    this.epicScanMessage,
    this.onScanGog,
    this.gogScanBusy = false,
    this.gogScanMessage,
    this.onScanUbisoft,
    this.ubisoftScanBusy = false,
    this.ubisoftScanMessage,
    this.onScanEa,
    this.eaScanBusy = false,
    this.eaScanMessage,
    this.onExit,
  });

  final WindowModeController windowMode;
  final double scale;
  final VoidCallback onClose;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleBorderless;
  final bool fullscreenOnLaunch;
  final ValueChanged<bool>? onFullscreenOnLaunch;
  final bool restoreOnExit;
  final ValueChanged<bool>? onRestoreOnExit;
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
  final String? romRoot;
  final VoidCallback? onPickRomRoot;
  final VoidCallback? onScanRoms;
  final bool romScanBusy;
  final String? romScanMessage;
  final VoidCallback? onScanEpic;
  final bool epicScanBusy;
  final String? epicScanMessage;
  final VoidCallback? onScanGog;
  final bool gogScanBusy;
  final String? gogScanMessage;
  final VoidCallback? onScanUbisoft;
  final bool ubisoftScanBusy;
  final String? ubisoftScanMessage;
  final VoidCallback? onScanEa;
  final bool eaScanBusy;
  final String? eaScanMessage;
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
                            key: const Key('settings-fullscreen-on-launch'),
                            label: 'Fullscreen on launch',
                            hint:
                                'Enter covers the display when launching a game (same as F11)',
                            value: fullscreenOnLaunch,
                            onChanged: onFullscreenOnLaunch ?? (_) {},
                          ),
                          _ToggleRow(
                            key: const Key('settings-restore-on-exit'),
                            label: 'Return to HomeDeck when game exits',
                            hint:
                                'Leave launch fullscreen and foreground HomeDeck when a local .exe/.lnk exits (store URIs best-effort only)',
                            value: restoreOnExit,
                            onChanged: onRestoreOnExit ?? (_) {},
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
                          const SizedBox(height: 16),
                          Text(
                            'ROM folder',
                            style: TextStyle(
                              color: HomeDeckColors.cyanDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 18 * scale,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan imports common ROM files (.iso, .nsp, .xci, .gba, .nds, .3ds, .cia, .wbfs, .rvz, .chd, .zip) as emulated Library tiles with {rom} args. Keyboard R (Ally SendKeys r) runs the same scan. Optional HOMEDECK_ROM_ROOT / HOMEDECK_EMULATOR override the folder and emulator for fixtures. If no emulator is configured, tiles still import — finish the emulator path via Manual Add / edit before launch.',
                            style: TextStyle(
                              color: HomeDeckColors.ink,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          if (romRoot != null && romRoot!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              romRoot!,
                              key: const Key('settings-rom-root-path'),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (onPickRomRoot != null || onScanRoms != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  if (onPickRomRoot != null)
                                    OutlinedButton(
                                      key: const Key('settings-pick-rom-root'),
                                      onPressed: romScanBusy
                                          ? null
                                          : onPickRomRoot,
                                      child: const Text(
                                        'Choose ROM folder',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  if (onScanRoms != null)
                                    FilledButton(
                                      key: const Key('settings-scan-roms'),
                                      onPressed:
                                          romScanBusy ? null : onScanRoms,
                                      child: Text(
                                        romScanBusy
                                            ? 'Scanning…'
                                            : 'Scan ROM folder',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (romScanMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              romScanMessage!,
                              key: const Key('settings-scan-roms-message'),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Epic Games',
                            style: TextStyle(
                              color: HomeDeckColors.cyanDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 18 * scale,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan imports installed Epic Games Launcher titles into Library (By app → Epic) via com.epicgames.launcher://apps/… when available (else resolved .exe). Keyboard E (Ally SendKeys e) runs the same scan without opening Settings. Optional HOMEDECK_EPIC_ROOT points at a fixture Manifests tree. No games-only filter — incomplete installs are skipped; everything else launchable is imported.',
                            style: TextStyle(
                              color: HomeDeckColors.ink,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          if (onScanEpic != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                key: const Key('settings-scan-epic'),
                                onPressed: epicScanBusy ? null : onScanEpic,
                                child: Text(
                                  epicScanBusy
                                      ? 'Scanning…'
                                      : 'Scan Epic Games',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (epicScanMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              epicScanMessage!,
                              key: const Key('settings-scan-epic-message'),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'GOG Galaxy',
                            style: TextStyle(
                              color: HomeDeckColors.cyanDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 18 * scale,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan imports installed GOG Galaxy titles into Library (By app → GOG) via goggalaxy://openGameView/… when available (else resolved .exe from goggame-*.info playTasks). Keyboard G (Ally SendKeys g) runs the same scan without opening Settings. Optional HOMEDECK_GOG_ROOT points at a fixture Games tree or install folder. No games-only filter — every launchable info file is imported.',
                            style: TextStyle(
                              color: HomeDeckColors.ink,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          if (onScanGog != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                key: const Key('settings-scan-gog'),
                                onPressed: gogScanBusy ? null : onScanGog,
                                child: Text(
                                  gogScanBusy
                                      ? 'Scanning…'
                                      : 'Scan GOG',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (gogScanMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              gogScanMessage!,
                              key: const Key('settings-scan-gog-message'),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Ubisoft Connect',
                            style: TextStyle(
                              color: HomeDeckColors.cyanDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 18 * scale,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan imports installed Ubisoft Connect titles into Library (By app → Ubisoft Connect) via uplay://launch/… when available (else resolved .exe). Keyboard U (Ally SendKeys u) runs the same scan without opening Settings. Optional HOMEDECK_UBISOFT_ROOT points at a fixture Games tree or install folder (ubisoftgame-*.info). No games-only filter — every launchable install is imported.',
                            style: TextStyle(
                              color: HomeDeckColors.ink,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          if (onScanUbisoft != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                key: const Key('settings-scan-ubisoft'),
                                onPressed:
                                    ubisoftScanBusy ? null : onScanUbisoft,
                                child: Text(
                                  ubisoftScanBusy
                                      ? 'Scanning…'
                                      : 'Scan Ubisoft Connect',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (ubisoftScanMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              ubisoftScanMessage!,
                              key: const Key('settings-scan-ubisoft-message'),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'EA App / Origin',
                            style: TextStyle(
                              color: HomeDeckColors.cyanDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 18 * scale,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan imports installed EA App / Origin titles into Library (By app → Origin / EA app) via origin://launchgame/… when available (else resolved .exe). Keyboard O (Ally SendKeys o) runs the same scan without opening Settings. Optional HOMEDECK_EA_ROOT points at a fixture Games tree or install folder (__Installer\\installerdata.xml). No games-only filter — every launchable install is imported.',
                            style: TextStyle(
                              color: HomeDeckColors.ink,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          if (onScanEa != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                key: const Key('settings-scan-ea'),
                                onPressed: eaScanBusy ? null : onScanEa,
                                child: Text(
                                  eaScanBusy ? 'Scanning…' : 'Scan EA App',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (eaScanMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              eaScanMessage!,
                              key: const Key('settings-scan-ea-message'),
                              style: const TextStyle(
                                color: HomeDeckColors.muted,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            'The library can hold games, emulators, and general applications. Scope is still an open product question. Manual Add (A), Steam (S), Start Menu (P), ROM (R), Epic (E), GOG (G), Ubisoft (U), EA (O), and pin to Home (H) stay unchanged.',
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
