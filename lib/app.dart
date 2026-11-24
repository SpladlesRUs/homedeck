import 'package:homedeck/core/device_status.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_screen.dart';
import 'package:material_ui/material_ui.dart';

class HomeDeckApp extends StatefulWidget {
  const HomeDeckApp({
    super.key,
    required this.controller,
    required this.windowMode,
    this.gamepad,
    this.deviceStatus,
    this.music,
  });

  final LibraryController controller;
  final WindowModeController windowMode;
  final GamepadSource? gamepad;
  final DeviceStatus? deviceStatus;
  final MenuMusicController? music;

  @override
  State<HomeDeckApp> createState() => _HomeDeckAppState();
}

class _HomeDeckAppState extends State<HomeDeckApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.windowMode.addFocusListener(_onWindowFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.windowMode.prepareInitialFrame();
      final prefs = widget.controller.state.window;
      if (prefs.fullscreen || prefs.borderless) {
        await widget.windowMode.apply(prefs.fullscreen, prefs.borderless);
      }
      await widget.music?.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.windowMode.removeFocusListener(_onWindowFocus);
    super.dispose();
  }

  void _onWindowFocus(bool focused) {
    if (focused) {
      widget.music?.unduck();
    } else {
      widget.music?.duck();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.music?.unduck();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        widget.music?.duck();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeDeck',
      debugShowCheckedModeBanner: false,
      theme: homeDeckTheme(),
      home: HomeScreen(
        controller: widget.controller,
        windowMode: widget.windowMode,
        gamepad: widget.gamepad,
        deviceStatus: widget.deviceStatus,
        music: widget.music,
      ),
    );
  }
}
