import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

/// Settings is a stub in milestone 1: window chrome plus open product questions.
class SettingsStub extends StatelessWidget {
  const SettingsStub({
    super.key,
    required this.windowMode,
    required this.scale,
    required this.onClose,
    required this.onToggleFullscreen,
    required this.onToggleBorderless,
  });

  final WindowModeController windowMode;
  final double scale;
  final VoidCallback onClose;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleBorderless;

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
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HomeDeckColors.deepIndigo,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: HomeDeckColors.gold, width: 3),
                ),
                child: Padding(
                  padding: EdgeInsets.all(32 * scale.clamp(0.8, 1.3)),
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
                              color: HomeDeckColors.cream,
                              fontWeight: FontWeight.w800,
                              fontSize: 32 * scale,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close, color: HomeDeckColors.cream),
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
                      const SizedBox(height: 20),
                      Text(
                        'Milestone 1',
                        style: TextStyle(
                          color: HomeDeckColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 18 * scale,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Apps are added manually. Installed-app discovery is not enabled yet.',
                        style: TextStyle(color: HomeDeckColors.cream, fontSize: 18, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The library can hold games, emulators, and general applications. Scope is still an open product question.',
                        style: TextStyle(color: HomeDeckColors.muted, fontSize: 16, height: 1.35),
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
                                color: HomeDeckColors.cream,
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
                        child: TextButton(
                          onPressed: onClose,
                          child: const Text(
                            'Close  ·  Esc',
                            style: TextStyle(
                              color: HomeDeckColors.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
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
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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
          color: HomeDeckColors.cream,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      subtitle: Text(hint, style: const TextStyle(color: HomeDeckColors.muted)),
      value: value,
      activeThumbColor: HomeDeckColors.voidNavy,
      activeTrackColor: HomeDeckColors.gold,
      onChanged: onChanged,
    );
  }
}
