import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:material_ui/material_ui.dart';

class AddTileSheet extends StatefulWidget {
  const AddTileSheet({
    super.key,
    required this.controller,
    required this.scale,
    required this.onClose,
    required this.onAdded,
  });

  final LibraryController controller;
  final double scale;
  final VoidCallback onClose;
  final ValueChanged<String> onAdded;

  @override
  State<AddTileSheet> createState() => _AddTileSheetState();
}

class _AddTileSheetState extends State<AddTileSheet> {
  TileKind _kind = TileKind.native;
  final _name = TextEditingController();
  final _uri = TextEditingController();
  final _args = TextEditingController(text: '{rom}');
  String? _nativePath;
  String? _emulatorPath;
  String? _romPath;
  Storefront _store = Storefront.other;
  ConsoleSystem _console = ConsoleSystem.other;
  bool _pinToHome = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _uri.dispose();
    _args.dispose();
    super.dispose();
  }

  Future<void> _pickNative() async {
    final path = await widget.controller.pickFile(
      label: 'Windows games',
      extensions: const ['exe', 'lnk'],
    );
    if (path == null || path.trim().isEmpty) {
      return;
    }
    setState(() {
      _nativePath = path;
      _uri.clear();
      _store = SourceInference.storeFrom(path);
      if (_name.text.trim().isEmpty) {
        _name.text = WindowsPaths.basenameWithoutExtension(path);
      }
    });
  }

  Future<void> _pickEmulator() async {
    final path = await widget.controller.pickFile(
      label: 'Emulator',
      extensions: const ['exe', 'lnk'],
    );
    if (path == null) {
      return;
    }
    setState(() {
      _emulatorPath = path;
      _console = SourceInference.consoleFrom(
        emulatorPath: path,
        romPath: _romPath,
        argsTemplate: _args.text,
      );
    });
  }

  Future<void> _pickRom() async {
    final path = await widget.controller.pickFile(
      label: 'ROM',
      extensions: const [
        'zip',
        '7z',
        'iso',
        'cue',
        'chd',
        'n64',
        'z64',
        'gba',
        'gb',
        'nes',
        'sfc',
        'smc',
        'nds',
        '3ds',
        'bin',
        'rom',
      ],
    );
    if (path == null) {
      return;
    }
    setState(() {
      _romPath = path;
      _console = SourceInference.consoleFrom(
        emulatorPath: _emulatorPath,
        romPath: path,
        argsTemplate: _args.text,
      );
      if (_name.text.trim().isEmpty) {
        _name.text = WindowsPaths.basenameWithoutExtension(path);
      }
    });
  }

  bool get _canSave {
    if (_busy) {
      return false;
    }
    if (_kind == TileKind.native) {
      final uri = _uri.text.trim();
      return (_nativePath != null && _nativePath!.trim().isNotEmpty) ||
          WindowsPaths.isLaunchUri(uri);
    }
    return _emulatorPath != null &&
        _emulatorPath!.trim().isNotEmpty &&
        _romPath != null &&
        _romPath!.trim().isNotEmpty;
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    setState(() => _busy = true);
    try {
      final target = _kind == TileKind.native
          ? _nativeTarget()
          : _emulatedTarget();
      if (target == null) {
        return;
      }
      final name = _name.text.trim().isEmpty
          ? (_kind == TileKind.emulated
                ? WindowsPaths.basenameWithoutExtension(_romPath!)
                : (WindowsPaths.isLaunchUri(_uri.text)
                      ? _uri.text.trim()
                      : WindowsPaths.basenameWithoutExtension(_nativePath!)))
          : _name.text.trim();
      final added = await widget.controller.addRecord(
        displayName: name,
        target: target,
        kind: _kind,
        console: _kind == TileKind.emulated ? _console : null,
        store: _kind == TileKind.native ? _store : null,
        pinToHome: _pinToHome,
      );
      if (mounted) {
        widget.onAdded(added.id);
      }
    } catch (_) {
      // Leave the sheet open on failure (Browse alone must not look like a
      // completed add with no icons/<id>.png).
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  LaunchTarget? _nativeTarget() {
    final uri = _uri.text.trim();
    if (WindowsPaths.isLaunchUri(uri)) {
      return LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: uri,
      );
    }
    final path = _nativePath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return LaunchTarget(
      platform: AppPlatform.windows,
      kind: WindowsPaths.isShortcut(path)
          ? LaunchTargetKind.windowsShortcut
          : LaunchTargetKind.windowsExecutable,
      value: path,
    );
  }

  LaunchTarget? _emulatedTarget() {
    final emulator = _emulatorPath?.trim();
    final rom = _romPath?.trim();
    if (emulator == null || rom == null) {
      return null;
    }
    return LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsEmulated,
      value: emulator,
      romPath: rom,
      argsTemplate: _args.text.trim().isEmpty ? '{rom}' : _args.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Actions(
      actions: {
        DismissOverlayIntent: CallbackAction<DismissOverlayIntent>(
          onInvoke: (_) {
            widget.onClose();
            return null;
          },
        ),
        ConfirmIntent: CallbackAction<ConfirmIntent>(
          onInvoke: (_) {
            // ignore: discarded_futures
            _save();
            return null;
          },
        ),
        // Home shortcuts map Enter / A to LaunchFocusedIntent, not
        // ConfirmIntent. Handle both so Add · A / Enter actually saves.
        LaunchFocusedIntent: CallbackAction<LaunchFocusedIntent>(
          onInvoke: (_) {
            // ignore: discarded_futures
            _save();
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
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              child: Material(
                key: const Key('add-tile-sheet'),
                color: const Color(0xFF1B2433),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: HomeDeckColors.cyan, width: 2),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24 * scale),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to library',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 24 * scale,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              key: const Key('add-kind-native'),
                              label: const Text('Native'),
                              selected: _kind == TileKind.native,
                              onSelected: (_) =>
                                  setState(() => _kind = TileKind.native),
                            ),
                            ChoiceChip(
                              key: const Key('add-kind-emulated'),
                              label: const Text('Emulated'),
                              selected: _kind == TileKind.emulated,
                              onSelected: (_) =>
                                  setState(() => _kind = TileKind.emulated),
                            ),
                          ],
                        ),
                        SizedBox(height: 16 * scale),
                        TextField(
                          key: const Key('add-name-field'),
                          controller: _name,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            labelStyle: TextStyle(color: HomeDeckColors.muted),
                          ),
                        ),
                        SizedBox(height: 12 * scale),
                        if (_kind == TileKind.native) ...[
                          _PathRow(
                            label: 'Game (.exe / .lnk)',
                            value: _nativePath,
                            buttonKey: const Key('add-pick-native'),
                            onPick: _pickNative,
                          ),
                          SizedBox(height: 8 * scale),
                          TextField(
                            key: const Key('add-uri-field'),
                            controller: _uri,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText:
                                  'Or paste a URI (steam://, Epic, GOG, Xbox)',
                              labelStyle: TextStyle(
                                color: HomeDeckColors.muted,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (WindowsPaths.isLaunchUri(value)) {
                                  _store = SourceInference.storeFrom(value);
                                }
                              });
                            },
                          ),
                          SizedBox(height: 8 * scale),
                          DropdownButtonFormField<Storefront>(
                            key: const Key('add-store'),
                            initialValue: _store,
                            dropdownColor: const Color(0xFF1B2433),
                            decoration: const InputDecoration(
                              labelText: 'Store',
                              labelStyle: TextStyle(
                                color: HomeDeckColors.muted,
                              ),
                            ),
                            items: [
                              for (final store in Storefront.values)
                                DropdownMenuItem(
                                  value: store,
                                  child: Text(store.label),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _store = value);
                              }
                            },
                          ),
                        ] else ...[
                          _PathRow(
                            label: 'Emulator',
                            value: _emulatorPath,
                            buttonKey: const Key('add-pick-emulator'),
                            onPick: _pickEmulator,
                          ),
                          SizedBox(height: 8 * scale),
                          _PathRow(
                            label: 'ROM',
                            value: _romPath,
                            buttonKey: const Key('add-pick-rom'),
                            onPick: _pickRom,
                          ),
                          SizedBox(height: 8 * scale),
                          TextField(
                            key: const Key('add-args-field'),
                            controller: _args,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Arguments ({rom} is the ROM path)',
                              labelStyle: TextStyle(
                                color: HomeDeckColors.muted,
                              ),
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          DropdownButtonFormField<ConsoleSystem>(
                            key: const Key('add-console'),
                            initialValue: _console,
                            dropdownColor: const Color(0xFF1B2433),
                            decoration: const InputDecoration(
                              labelText: 'Console',
                              labelStyle: TextStyle(
                                color: HomeDeckColors.muted,
                              ),
                            ),
                            items: [
                              for (final console in ConsoleSystem.values)
                                DropdownMenuItem(
                                  value: console,
                                  child: Text(console.label),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _console = value);
                              }
                            },
                          ),
                        ],
                        CheckboxListTile(
                          key: const Key('add-pin-home'),
                          value: _pinToHome,
                          onChanged: (value) =>
                              setState(() => _pinToHome = value ?? true),
                          title: const Text(
                            'Also add to Home',
                            style: TextStyle(color: Colors.white),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        SizedBox(height: 12 * scale),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: widget.onClose,
                              child: const Text('Cancel  ·  B'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              key: const Key('add-save'),
                              onPressed: _canSave ? _save : null,
                              child: const Text('Add  ·  A'),
                            ),
                          ],
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

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.label,
    required this.value,
    required this.buttonKey,
    required this.onPick,
  });

  final String label;
  final String? value;
  final Key buttonKey;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value == null || value!.isEmpty ? label : value!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == null ? HomeDeckColors.muted : Colors.white,
            ),
          ),
        ),
        TextButton(
          key: buttonKey,
          onPressed: onPick,
          child: const Text('Browse'),
        ),
      ],
    );
  }
}
