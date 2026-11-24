import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_screen.dart';
import 'package:material_ui/material_ui.dart';

class HomeDeckApp extends StatefulWidget {
  const HomeDeckApp({
    super.key,
    required this.controller,
    required this.windowMode,
  });

  final LibraryController controller;
  final WindowModeController windowMode;

  @override
  State<HomeDeckApp> createState() => _HomeDeckAppState();
}

class _HomeDeckAppState extends State<HomeDeckApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.windowMode.prepareInitialFrame();
      final prefs = widget.controller.state.window;
      if (prefs.fullscreen || prefs.borderless) {
        await widget.windowMode.apply(prefs.fullscreen, prefs.borderless);
      }
    });
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
      ),
    );
  }
}
