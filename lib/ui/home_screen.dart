import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:homedeck/core/device_status.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:homedeck/ui/launch_error_view.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:homedeck/ui/settings_stub.dart';
import 'package:material_ui/material_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.windowMode,
    this.gamepad,
    this.deviceStatus,
  });

  /// Widget tests disable the clock so `pumpAndSettle` can finish.
  static bool tickClock = true;

  /// Tests freeze the clock for screenshots.
  static DateTime Function() clock = DateTime.now;

  final LibraryController controller;
  final WindowModeController windowMode;
  final GamepadSource? gamepad;
  final DeviceStatus? deviceStatus;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _focusedId;
  String? _hoveredId;
  bool _moveMode = false;
  bool _settingsOpen = false;
  bool _detailsOpen = false;
  LaunchFailure? _failure;
  String? _failureApp;
  String? _pendingRemoveId;
  int _page = 0;
  HomeTab _tab = HomeTab.home;
  Timer? _clock;
  DateTime _now = HomeScreen.clock();
  DateTime _lastConfirm = DateTime.fromMillisecondsSinceEpoch(0);
  final _focusNodes = <String, FocusNode>{};

  LibraryController get _library => widget.controller;
  WindowModeController get _window => widget.windowMode;
  GamepadSource get _gamepad => widget.gamepad ?? IdleGamepadSource();
  DeviceStatus get _status => widget.deviceStatus ?? MemoryDeviceStatus();

  @override
  void initState() {
    super.initState();
    _library.addListener(_onLibrary);
    _window.addListener(_onLibrary);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _gamepad.start(_onGamepad);
    _status.start(_onLibrary);
    if (HomeScreen.tickClock) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _now = HomeScreen.clock());
        }
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _clock?.cancel();
    _gamepad.stop();
    _status.stop();
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

  bool get _overlayOpen =>
      _failure != null ||
      _settingsOpen ||
      _detailsOpen ||
      _pendingRemoveId != null;

  Map<ShortcutActivator, Intent> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.enter): const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonA):
        const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.delete): const RemoveFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace): const RemoveFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const DismissOverlayIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonB):
        const DismissOverlayIntent(),
    const SingleActivator(LogicalKeyboardKey.f11): const ToggleFullscreenIntent(),
    const SingleActivator(LogicalKeyboardKey.keyM): const ToggleMoveModeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA): const AddAppIntent(),
    const SingleActivator(LogicalKeyboardKey.comma, control: true):
        const OpenSettingsIntent(),
    const SingleActivator(LogicalKeyboardKey.equal): const OpenMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.add): const OpenMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.minus): const OpenDetailsIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonStart):
        const OpenMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonSelect):
        const OpenDetailsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF): const ToggleFavoriteIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketLeft): const PrevTabIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketRight): const NextTabIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonLeft1):
        const PrevTabIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonRight1):
        const NextTabIntent(),
    const SingleActivator(LogicalKeyboardKey.pageUp): const PrevTabIntent(),
    const SingleActivator(LogicalKeyboardKey.pageDown): const NextTabIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const DirectionalFocusIntent(TraversalDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const DirectionalFocusIntent(TraversalDirection.right),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const DirectionalFocusIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const DirectionalFocusIntent(TraversalDirection.down),
  };

  Map<Type, Action<Intent>> _actions(HomeDeckMetrics metrics) {
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
      OpenMenuIntent: CallbackAction<OpenMenuIntent>(
        onInvoke: (_) {
          setState(() => _settingsOpen = true);
          return null;
        },
      ),
      OpenDetailsIntent: CallbackAction<OpenDetailsIntent>(
        onInvoke: (_) {
          _openDetails();
          return null;
        },
      ),
      NextTabIntent: CallbackAction<NextTabIntent>(
        onInvoke: (_) {
          _shiftTab(1);
          return null;
        },
      ),
      PrevTabIntent: CallbackAction<PrevTabIntent>(
        onInvoke: (_) {
          _shiftTab(-1);
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
          if (_overlayOpen) {
            return null;
          }
          if (_moveMode && _focusedId != null && _focusedId != addTileId) {
            _library.moveFocused(_focusedId!, intent.direction, metrics.columns);
            return null;
          }
          _moveSelection(intent.direction, metrics);
          return null;
        },
      ),
    };
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (_gamepad.isConnected && _isGamepadKey(event.logicalKey)) {
      return true;
    }
    return false;
  }

  bool _isGamepadKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.gameButtonX ||
        key == LogicalKeyboardKey.gameButtonY ||
        key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonRight1 ||
        key == LogicalKeyboardKey.gameButtonStart ||
        key == LogicalKeyboardKey.gameButtonSelect;
  }

  void _onGamepad(GamepadButton button) {
    if (!mounted) {
      return;
    }
    final metrics = HomeDeckMetrics.of(MediaQuery.sizeOf(context));
    switch (button) {
      case GamepadButton.a:
        _handleConfirm();
      case GamepadButton.b:
        _dismiss();
      case GamepadButton.lb:
        _shiftTab(-1);
      case GamepadButton.rb:
        _shiftTab(1);
      case GamepadButton.start:
        setState(() => _settingsOpen = true);
      case GamepadButton.back:
        _openDetails();
      case GamepadButton.dpadLeft:
        if (!_overlayOpen) {
          _moveSelection(TraversalDirection.left, metrics);
        }
      case GamepadButton.dpadRight:
        if (!_overlayOpen) {
          _moveSelection(TraversalDirection.right, metrics);
        }
      case GamepadButton.dpadUp:
        if (!_overlayOpen) {
          _moveSelection(TraversalDirection.up, metrics);
        }
      case GamepadButton.dpadDown:
        if (!_overlayOpen) {
          _moveSelection(TraversalDirection.down, metrics);
        }
      case GamepadButton.lt:
      case GamepadButton.rt:
      case GamepadButton.x:
      case GamepadButton.y:
        break;
    }
  }

  void _shiftTab(int delta) {
    if (_overlayOpen) {
      return;
    }
    final values = HomeTab.values;
    final next = (values.indexOf(_tab) + delta) % values.length;
    setState(() => _tab = values[next < 0 ? values.length - 1 : next]);
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
    final now = DateTime.now();
    if (now.difference(_lastConfirm) < const Duration(milliseconds: 220)) {
      return;
    }
    _lastConfirm = now;
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
    if (_detailsOpen) {
      setState(() => _detailsOpen = false);
      return;
    }
    if (_moveMode) {
      setState(() => _moveMode = false);
      return;
    }
    if (_tab != HomeTab.home && _tab != HomeTab.allApps) {
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
    if (_detailsOpen) {
      setState(() => _detailsOpen = false);
      return;
    }
    if (_moveMode) {
      setState(() => _moveMode = false);
    }
  }

  void _openDetails() {
    if (_overlayOpen) {
      return;
    }
    if (_focusedRecord == null && _focusedId != addTileId) {
      return;
    }
    setState(() => _detailsOpen = true);
  }

  AppRecord? get _focusedRecord {
    final id = _focusedId;
    if (id == null || id == addTileId) {
      return null;
    }
    return _library.byId(id);
  }

  String get _selectedTitle {
    if (_focusedId == addTileId) {
      return 'Add app';
    }
    return _focusedRecord?.displayName ?? 'HomeDeck';
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
      _focusId(added.id);
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

  List<String> get _gridFocusableIds => [
    ..._library.apps.map((app) => app.id),
    addTileId,
  ];

  FocusNode _nodeFor(String id) {
    return _focusNodes.putIfAbsent(id, FocusNode.new);
  }

  int _pageCount(HomeDeckMetrics metrics) =>
      HomeGrid.pageCountFor(_gridFocusableIds.length, metrics.pageSize);

  void _focusId(String id) {
    final ids = _gridFocusableIds;
    final index = ids.indexOf(id);
    setState(() {
      _focusedId = id;
      if (index >= 0) {
        final metrics = HomeDeckMetrics.of(MediaQuery.sizeOf(context));
        _page = index ~/ metrics.pageSize;
      }
    });
    _nodeFor(id).requestFocus();
  }

  void _goToPage(int page) {
    setState(() {
      _page = page;
      final ids = _gridFocusableIds;
      final metrics = HomeDeckMetrics.of(MediaQuery.sizeOf(context));
      final start = page * metrics.pageSize;
      if (start < ids.length) {
        _focusedId = ids[start];
      }
    });
    final id = _focusedId;
    if (id != null) {
      _nodeFor(id).requestFocus();
    }
  }

  void _moveSelection(TraversalDirection direction, HomeDeckMetrics metrics) {
    final ids = _gridFocusableIds;
    if (ids.isEmpty) {
      return;
    }
    var index = ids.indexOf(_focusedId ?? ids.first);
    if (index < 0) {
      index = 0;
    }
    final columns = metrics.columns;
    final next = switch (direction) {
      TraversalDirection.left => index - 1,
      TraversalDirection.right => index + 1,
      TraversalDirection.up => index - columns,
      TraversalDirection.down => index + columns,
    };
    if (next < 0) {
      _focusId(ids.last);
      return;
    }
    if (next >= ids.length) {
      _focusId(ids.first);
      return;
    }
    _focusId(ids[next]);
  }

  int _displayPage(HomeDeckMetrics metrics) {
    final ids = _gridFocusableIds;
    final index = ids.indexOf(_focusedId ?? '');
    if (index >= 0) {
      return index ~/ metrics.pageSize;
    }
    return _page.clamp(0, _pageCount(metrics) - 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final metrics = HomeDeckMetrics.of(size);
    final pages = _pageCount(metrics);
    final page = _displayPage(metrics);
    final focused = _focusedRecord;
    final File? artFile = focused == null ? null : _library.iconFile(focused);

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: _actions(metrics),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Focus(
            child: Scaffold(
              body: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: ArtBackdrop(
                      key: ValueKey(_focusedId ?? 'none'),
                      color: backdropColorFor(_focusedId ?? 'home'),
                      imageFile: artFile,
                    ),
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          metrics.padding,
                          14 * metrics.scale,
                          metrics.padding,
                          8 * metrics.scale,
                        ),
                        child: Row(
                          children: [
                            ProfileCluster(metrics: metrics),
                            Expanded(
                              child: Center(
                                child: TitlePill(
                                  title: _selectedTitle,
                                  metrics: metrics,
                                ),
                              ),
                            ),
                            StatusCluster(
                              metrics: metrics,
                              now: _now,
                              batteryPercent: _status.batteryPercent,
                              fullscreen: _window.isFullscreen,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 36 * metrics.scale,
                            vertical: 4 * metrics.scale,
                          ),
                          child: GlassPanel(
                            child: _tabBody(metrics, page, pages),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: 8 * metrics.scale,
                          bottom: 52 * metrics.scale,
                        ),
                        child: TabDock(
                          metrics: metrics,
                          active: _tab,
                          onSelect: (tab) => setState(() => _tab = tab),
                        ),
                      ),
                    ],
                  ),
                  CornerHints(
                    metrics: metrics,
                    onBack: _dismiss,
                    onDetails: _openDetails,
                    onSelect: _handleConfirm,
                    onMenu: () => setState(() => _settingsOpen = true),
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
                      onExit: () => _window.close(),
                    ),
                  if (_detailsOpen)
                    _DetailsSheet(
                      name: _selectedTitle,
                      path: focused == null || focused.targets.isEmpty
                          ? null
                          : focused.targets.values.first.value,
                      scale: metrics.scale,
                      onClose: () => setState(() => _detailsOpen = false),
                      onRemove: focused == null
                          ? null
                          : () {
                              setState(() {
                                _detailsOpen = false;
                                _pendingRemoveId = focused.id;
                              });
                            },
                    ),
                  if (_pendingRemoveId != null)
                    _RemoveConfirm(
                      name: _library.byId(_pendingRemoveId!)?.displayName ??
                          'this app',
                      scale: metrics.scale,
                      onConfirm: () {
                        final id = _pendingRemoveId!;
                        setState(() => _pendingRemoveId = null);
                        _library.remove(id);
                      },
                      onCancel: () => setState(() => _pendingRemoveId = null),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBody(HomeDeckMetrics metrics, int page, int pages) {
    switch (_tab) {
      case HomeTab.games:
        return PlaceholderTab(title: 'Games', metrics: metrics);
      case HomeTab.achievements:
        return PlaceholderTab(title: 'Achievements', metrics: metrics);
      case HomeTab.friends:
        return PlaceholderTab(title: 'Friends', metrics: metrics);
      case HomeTab.home:
      case HomeTab.allApps:
        return Column(
          children: [
            Expanded(
              child: HomeGrid(
                controller: _library,
                metrics: metrics,
                page: page,
                focusedId: _focusedId,
                hoveredId: _hoveredId,
                moveMode: _moveMode,
                hideEmpty: _tab == HomeTab.allApps,
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
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SubtlePageDots(
                count: pages,
                page: page,
                onSelect: _goToPage,
              ),
            ),
          ],
        );
    }
  }
}

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.name,
    required this.scale,
    required this.onClose,
    this.path,
    this.onRemove,
  });

  final String name;
  final String? path;
  final double scale;
  final VoidCallback onClose;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B2433),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: HomeDeckColors.cyan, width: 2),
            ),
            child: Padding(
              padding: EdgeInsets.all(28 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    key: const Key('details-title'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24 * scale,
                    ),
                  ),
                  if (path != null) ...[
                    SizedBox(height: 10 * scale),
                    Text(
                      path!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HomeDeckColors.muted,
                        fontSize: 13 * scale,
                      ),
                    ),
                  ],
                  SizedBox(height: 22 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(onPressed: onClose, child: const Text('Close  ·  B')),
                      if (onRemove != null) ...[
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: onRemove,
                          style: FilledButton.styleFrom(
                            backgroundColor: HomeDeckColors.danger,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
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
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B2433),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: HomeDeckColors.cyan, width: 3),
            ),
            child: Padding(
              padding: EdgeInsets.all(28 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Remove from library?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24 * scale,
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  Text(
                    name,
                    style: TextStyle(
                      color: HomeDeckColors.cyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 20 * scale,
                    ),
                  ),
                  SizedBox(height: 22 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: const Text(
                          'Cancel  ·  B',
                          style: TextStyle(color: HomeDeckColors.muted, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeDeckColors.danger,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Remove  ·  A'),
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
