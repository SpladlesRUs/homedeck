import 'dart:async';

import 'package:flutter/services.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:homedeck/ui/launch_error_view.dart';
import 'package:homedeck/ui/settings_stub.dart';
import 'package:material_ui/material_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.windowMode,
  });

  /// Widget tests disable the clock so `pumpAndSettle` can finish.
  static bool tickClock = true;

  final LibraryController controller;
  final WindowModeController windowMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _focusedId;
  String? _hoveredId;
  bool _moveMode = false;
  bool _settingsOpen = false;
  LaunchFailure? _failure;
  String? _failureApp;
  String? _pendingRemoveId;
  Timer? _clock;
  DateTime _now = DateTime.now();
  final _focusNodes = <String, FocusNode>{};

  LibraryController get _library => widget.controller;
  WindowModeController get _window => widget.windowMode;

  @override
  void initState() {
    super.initState();
    _library.addListener(_onLibrary);
    _window.addListener(_onLibrary);
    if (HomeScreen.tickClock) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _library.removeListener(_onLibrary);
    _window.removeListener(_onLibrary);
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onLibrary() {
    if (mounted) {
      setState(() {});
    }
  }

  Map<ShortcutActivator, Intent> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.enter): const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.delete): const RemoveFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace): const RemoveFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const DismissOverlayIntent(),
    const SingleActivator(LogicalKeyboardKey.f11): const ToggleFullscreenIntent(),
    const SingleActivator(LogicalKeyboardKey.keyM): const ToggleMoveModeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA): const AddAppIntent(),
    const SingleActivator(LogicalKeyboardKey.comma, control: true):
        const OpenSettingsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF): const ToggleFavoriteIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const DirectionalFocusIntent(TraversalDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const DirectionalFocusIntent(TraversalDirection.right),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const DirectionalFocusIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const DirectionalFocusIntent(TraversalDirection.down),
  };

  Map<Type, Action<Intent>> _actions(int columns) {
    return {
      LaunchFocusedIntent: CallbackAction<LaunchFocusedIntent>(
        onInvoke: (_) {
          _handleConfirm();
          return null;
        },
      ),
      ConfirmIntent: CallbackAction<ConfirmIntent>(
        onInvoke: (_) {
          _handleConfirm();
          return null;
        },
      ),
      RemoveFocusedIntent: CallbackAction<RemoveFocusedIntent>(
        onInvoke: (_) {
          _requestRemove();
          return null;
        },
      ),
      AddAppIntent: CallbackAction<AddAppIntent>(
        onInvoke: (_) {
          _addApp();
          return null;
        },
      ),
      ToggleMoveModeIntent: CallbackAction<ToggleMoveModeIntent>(
        onInvoke: (_) {
          setState(() => _moveMode = !_moveMode);
          return null;
        },
      ),
      ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
        onInvoke: (_) {
          _toggleFullscreen();
          return null;
        },
      ),
      ToggleBorderlessIntent: CallbackAction<ToggleBorderlessIntent>(
        onInvoke: (_) {
          _toggleBorderless();
          return null;
        },
      ),
      OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
        onInvoke: (_) {
          setState(() => _settingsOpen = true);
          return null;
        },
      ),
      DismissOverlayIntent: CallbackAction<DismissOverlayIntent>(
        onInvoke: (_) {
          _dismiss();
          return null;
        },
      ),
      ToggleFavoriteIntent: CallbackAction<ToggleFavoriteIntent>(
        onInvoke: (_) {
          final id = _focusedId;
          if (id != null && id != addTileId) {
            _library.toggleFavorite(id);
          }
          return null;
        },
      ),
      DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
        onInvoke: (intent) {
          if (_failure != null || _settingsOpen || _pendingRemoveId != null) {
            return null;
          }
          if (_moveMode &&
              _focusedId != null &&
              _focusedId != addTileId) {
            _library.moveFocused(_focusedId!, intent.direction, columns);
            return null;
          }
          _moveSelection(intent.direction, columns);
          return null;
        },
      ),
    };
  }

  Future<void> _toggleFullscreen() async {
    await _window.toggleFullscreen();
    await _library.setWindowPrefs(
      WindowPrefs(
        fullscreen: _window.isFullscreen,
        borderless: _window.isBorderless,
      ),
    );
  }

  Future<void> _toggleBorderless() async {
    await _window.toggleBorderless();
    await _library.setWindowPrefs(
      WindowPrefs(
        fullscreen: _window.isFullscreen,
        borderless: _window.isBorderless,
      ),
    );
  }

  void _handleConfirm() {
    if (_failure != null) {
      setState(() {
        _failure = null;
        _failureApp = null;
      });
      return;
    }
    if (_pendingRemoveId != null) {
      final id = _pendingRemoveId!;
      setState(() => _pendingRemoveId = null);
      _library.remove(id);
      return;
    }
    if (_settingsOpen) {
      setState(() => _settingsOpen = false);
      return;
    }
    if (_moveMode) {
      setState(() => _moveMode = false);
      return;
    }
    if (_focusedId == addTileId) {
      _addApp();
      return;
    }
    final focused = _focusedRecord;
    if (focused != null) {
      _launch(focused);
    }
  }

  void _dismiss() {
    if (_failure != null) {
      setState(() {
        _failure = null;
        _failureApp = null;
      });
      return;
    }
    if (_pendingRemoveId != null) {
      setState(() => _pendingRemoveId = null);
      return;
    }
    if (_settingsOpen) {
      setState(() => _settingsOpen = false);
      return;
    }
    if (_moveMode) {
      setState(() => _moveMode = false);
    }
  }

  AppRecord? get _focusedRecord {
    final id = _focusedId;
    if (id == null || id == addTileId) {
      return null;
    }
    return _library.byId(id);
  }

  Future<void> _launch(AppRecord app) async {
    if (_moveMode) {
      setState(() => _moveMode = false);
      return;
    }
    final outcome = await _library.launch(app.id);
    if (!mounted) {
      return;
    }
    if (outcome is LaunchFailure) {
      setState(() {
        _failure = outcome;
        _failureApp = app.displayName;
      });
    }
  }

  Future<void> _addApp() async {
    final added = await _library.addFromPicker();
    if (added != null && mounted) {
      setState(() => _focusedId = added.id);
    }
  }

  void _requestRemove() {
    final id = _focusedId;
    if (id == null || id == addTileId) {
      return;
    }
    setState(() => _pendingRemoveId = id);
  }

  void _onReorderDrop(String draggedId, String ontoId) {
    final ids = _library.apps.map((app) => app.id).toList();
    final from = ids.indexOf(draggedId);
    final to = ids.indexOf(ontoId);
    if (from >= 0 && to >= 0) {
      _library.reorder(from, to);
    }
  }

  List<String> get _focusableIds => [
    ..._library.apps.map((app) => app.id),
    addTileId,
  ];

  FocusNode _nodeFor(String id) {
    return _focusNodes.putIfAbsent(id, FocusNode.new);
  }

  void _moveSelection(TraversalDirection direction, int columns) {
    final ids = _focusableIds;
    if (ids.isEmpty) {
      return;
    }
    var index = ids.indexOf(_focusedId ?? ids.first);
    if (index < 0) {
      index = 0;
    }
    final next = switch (direction) {
      TraversalDirection.left => index - 1,
      TraversalDirection.right => index + 1,
      TraversalDirection.up => index - columns,
      TraversalDirection.down => index + columns,
    };
    if (next < 0 || next >= ids.length) {
      return;
    }
    final id = ids[next];
    setState(() => _focusedId = id);
    _nodeFor(id).requestFocus();
  }

  String _clockLabel() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final metrics = HomeDeckMetrics.of(size);
    final overlayOpen =
        _failure != null || _settingsOpen || _pendingRemoveId != null;

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: _actions(metrics.columns),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Focus(
            child: Scaffold(
              body: Stack(
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.6),
                        radius: 1.15,
                        colors: [
                          Color(0xFF24305E),
                          HomeDeckColors.voidNavy,
                        ],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                  Column(
                    children: [
                      _Header(
                        metrics: metrics,
                        clock: _clockLabel(),
                        moveMode: _moveMode,
                        fullscreen: _window.isFullscreen,
                        onSettings: () => setState(() => _settingsOpen = true),
                      ),
                      Expanded(
                        child: HomeGrid(
                          controller: _library,
                          metrics: metrics,
                          focusedId: _focusedId,
                          hoveredId: _hoveredId,
                          moveMode: _moveMode,
                          onFocus: (id) {
                            if (_focusedId != id) {
                              setState(() => _focusedId = id);
                            }
                          },
                          onHover: (id) => setState(() => _hoveredId = id),
                          onLaunch: _launch,
                          onAdd: _addApp,
                          onReorderDrop: _onReorderDrop,
                          focusNodeFor: _nodeFor,
                        ),
                      ),
                      _Footer(metrics: metrics, moveMode: _moveMode),
                    ],
                  ),
                  if (_failure != null)
                    LaunchErrorView(
                      key: const Key('launch-error-dialog'),
                      failure: _failure!,
                      appName: _failureApp ?? 'This app',
                      scale: metrics.scale,
                      onDismiss: _dismiss,
                    ),
                  if (_settingsOpen)
                    SettingsStub(
                      windowMode: _window,
                      scale: metrics.scale,
                      onClose: () => setState(() => _settingsOpen = false),
                      onToggleFullscreen: _toggleFullscreen,
                      onToggleBorderless: _toggleBorderless,
                    ),
                  if (_pendingRemoveId != null)
                    _RemoveConfirm(
                      name: _library.byId(_pendingRemoveId!)?.displayName ?? 'this app',
                      scale: metrics.scale,
                      onConfirm: () {
                        final id = _pendingRemoveId!;
                        setState(() => _pendingRemoveId = null);
                        _library.remove(id);
                      },
                      onCancel: () => setState(() => _pendingRemoveId = null),
                    ),
                  if (overlayOpen) const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.metrics,
    required this.clock,
    required this.moveMode,
    required this.fullscreen,
    required this.onSettings,
  });

  final HomeDeckMetrics metrics;
  final String clock;
  final bool moveMode;
  final bool fullscreen;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.padding,
        20 * metrics.scale,
        metrics.padding,
        8 * metrics.scale,
      ),
      child: Row(
        children: [
          HomeDeckMark(size: 64 * metrics.scale),
          SizedBox(width: 14 * metrics.scale),
          Text(
            'HomeDeck',
            style: TextStyle(
              color: HomeDeckColors.cream,
              fontWeight: FontWeight.w900,
              fontSize: metrics.titleSize,
              letterSpacing: 0.6,
            ),
          ),
          if (moveMode) ...[
            SizedBox(width: 16 * metrics.scale),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: HomeDeckColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'REARRANGE',
                style: TextStyle(
                  color: HomeDeckColors.voidNavy,
                  fontWeight: FontWeight.w900,
                  fontSize: 16 * metrics.scale,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (fullscreen)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'FULLSCREEN',
                key: const Key('fullscreen-badge'),
                style: TextStyle(
                  color: HomeDeckColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 16 * metrics.scale,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          Text(
            clock,
            style: TextStyle(
              color: HomeDeckColors.cream,
              fontWeight: FontWeight.w700,
              fontSize: 28 * metrics.scale,
            ),
          ),
          IconButton(
            key: const Key('settings-button'),
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: Icon(
              Icons.settings_rounded,
              color: HomeDeckColors.muted,
              size: 32 * metrics.scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.metrics, required this.moveMode});

  final HomeDeckMetrics metrics;
  final bool moveMode;

  @override
  Widget build(BuildContext context) {
    final text = moveMode
        ? 'Arrows move tile  ·  Enter or Esc exit  ·  Drag to reorder'
        : 'Arrows move  ·  Enter launch  ·  Delete remove  ·  M rearrange  ·  F11 fullscreen';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.padding,
        4,
        metrics.padding,
        18 * metrics.scale,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: HomeDeckColors.muted,
          fontSize: metrics.hintSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RemoveConfirm extends StatelessWidget {
  const _RemoveConfirm({
    required this.name,
    required this.scale,
    required this.onConfirm,
    required this.onCancel,
  });

  final String name;
  final double scale;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HomeDeckColors.deepIndigo,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: HomeDeckColors.gold, width: 3),
            ),
            child: Padding(
              padding: EdgeInsets.all(32 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Remove from library?',
                    style: TextStyle(
                      color: HomeDeckColors.cream,
                      fontWeight: FontWeight.w800,
                      fontSize: 28 * scale,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Text(
                    name,
                    style: TextStyle(
                      color: HomeDeckColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 24 * scale,
                    ),
                  ),
                  SizedBox(height: 24 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: const Text(
                          'Cancel  ·  Esc',
                          style: TextStyle(color: HomeDeckColors.muted, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeDeckColors.danger,
                          foregroundColor: HomeDeckColors.cream,
                        ),
                        child: const Text('Remove  ·  Enter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
