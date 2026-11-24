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
import 'package:homedeck/ui/menu_chrome.dart';
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
  int _page = 0;
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
      DismissOverlayIntent: CallbackAction<DismissOverlayIntent>(
        onInvoke: (_) {
          _dismiss();
          return null;
        },
      ),
      ToggleFavoriteIntent: CallbackAction<ToggleFavoriteIntent>(
        onInvoke: (_) {
          final id = _focusedId;
          if (id != null && !_isChrome(id)) {
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
              !_isChrome(_focusedId!)) {
            _library.moveFocused(_focusedId!, intent.direction, metrics.columns);
            return null;
          }
          _moveSelection(intent.direction, metrics);
          return null;
        },
      ),
    };
  }

  bool _isChrome(String id) =>
      id == addTileId || dockIds.contains(id);

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
    final id = _focusedId;
    if (id == addTileId || id == dockAddId) {
      _addApp();
      return;
    }
    if (id == dockSettingsId) {
      setState(() => _settingsOpen = true);
      return;
    }
    if (id == dockFullscreenId) {
      _toggleFullscreen();
      return;
    }
    if (id == dockLibraryId) {
      _goToPage(0);
      return;
    }
    if (id == dockExitId) {
      _window.close();
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
    if (id == null || _isChrome(id)) {
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
      _focusId(added.id);
    }
  }

  void _requestRemove() {
    final id = _focusedId;
    if (id == null || _isChrome(id)) {
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
    if (dockIds.contains(_focusedId)) {
      _moveDock(direction, metrics);
      return;
    }
    final ids = _gridFocusableIds;
    if (ids.isEmpty) {
      return;
    }
    var index = ids.indexOf(_focusedId ?? ids.first);
    if (index < 0) {
      index = 0;
    }
    final columns = metrics.columns;
    final pageSize = metrics.pageSize;
    final row = (index % pageSize) ~/ columns;

    if (direction == TraversalDirection.down &&
        row >= metrics.rows - 1) {
      _focusId(dockLibraryId);
      return;
    }

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

  void _moveDock(TraversalDirection direction, HomeDeckMetrics metrics) {
    final index = dockIds.indexOf(_focusedId ?? dockLibraryId);
    if (direction == TraversalDirection.up) {
      final ids = _gridFocusableIds;
      final start = _page * metrics.pageSize;
      final bottom = (start + metrics.pageSize - metrics.columns)
          .clamp(0, ids.length - 1);
      _focusId(ids[bottom]);
      return;
    }
    if (direction == TraversalDirection.down) {
      return;
    }
    final delta = direction == TraversalDirection.left ? -1 : 1;
    final next = (index + delta) % dockIds.length;
    _focusId(dockIds[next < 0 ? dockIds.length - 1 : next]);
  }

  String _clockLabel() {
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');
    final suffix = _now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final metrics = HomeDeckMetrics.of(size);
    final pages = _pageCount(metrics);
    final page = _displayPage(metrics);
    final overlayOpen =
        _failure != null || _settingsOpen || _pendingRemoveId != null;

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
                  const MenuBackdrop(),
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          metrics.padding,
                          18 * metrics.scale,
                          metrics.padding,
                          10 * metrics.scale,
                        ),
                        child: Row(
                          children: [
                            ProfileBadge(metrics: metrics),
                            const Spacer(),
                            PageDots(
                              count: pages,
                              page: page,
                              onSelect: _goToPage,
                            ),
                            const Spacer(),
                            if (_moveMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  'REARRANGE',
                                  style: TextStyle(
                                    color: HomeDeckColors.cyanDeep,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13 * metrics.scale,
                                  ),
                                ),
                              ),
                            if (_window.isFullscreen)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  'FULLSCREEN',
                                  key: const Key('fullscreen-badge'),
                                  style: TextStyle(
                                    color: HomeDeckColors.cyanDeep,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12 * metrics.scale,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            Text(
                              _clockLabel(),
                              style: TextStyle(
                                color: HomeDeckColors.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 20 * metrics.scale,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: HomeGrid(
                          controller: _library,
                          metrics: metrics,
                          page: page,
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
                      Center(
                        child: BottomDock(
                          metrics: metrics,
                          focusedId: _focusedId,
                          fullscreen: _window.isFullscreen,
                          onFocus: (id) => setState(() => _focusedId = id),
                          onSettings: () => setState(() => _settingsOpen = true),
                          onAdd: _addApp,
                          onFullscreen: _toggleFullscreen,
                          onLibrary: () => _goToPage(0),
                          onExit: () => _window.close(),
                          focusNodeFor: _nodeFor,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8 * metrics.scale),
                        child: Text(
                          _moveMode
                              ? 'Arrows move tile  ·  Enter or Esc exit'
                              : 'Arrows move  ·  Enter launch  ·  Delete remove  ·  F11 fullscreen',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: HomeDeckColors.muted,
                            fontSize: metrics.hintSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (pages > 1 && page > 0)
                    PageEdgeTab(left: true, onPressed: () => _goToPage(page - 1)),
                  if (pages > 1 && page < pages - 1)
                    PageEdgeTab(
                      left: false,
                      onPressed: () => _goToPage(page + 1),
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
              color: Colors.white,
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
                      color: HomeDeckColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 24 * scale,
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  Text(
                    name,
                    style: TextStyle(
                      color: HomeDeckColors.cyanDeep,
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
                          'Cancel  ·  Esc',
                          style: TextStyle(
                            color: HomeDeckColors.muted,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeDeckColors.danger,
                          foregroundColor: Colors.white,
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
