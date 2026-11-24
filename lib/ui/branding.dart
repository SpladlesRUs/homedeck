import 'package:material_ui/material_ui.dart';

/// Original HomeDeck palette. Inspired by living-room handhelds, not Nintendo.
class HomeDeckColors {
  static const canvas = Color(0xFF1B2433);
  static const canvasDeep = Color(0xFF0E141E);
  static const glass = Color(0x99101824);
  static const glassEdge = Color(0x55FFFFFF);
  static const tileEmpty = Color(0x33FFFFFF);
  static const tileEmptyEdge = Color(0x22FFFFFF);
  static const ink = Color(0xFFF4F7FB);
  static const muted = Color(0xFFC5CDD8);
  static const cyan = Color(0xFF7AE7FF);
  static const cyanDeep = Color(0xFF2EC4FF);
  static const gold = Color(0xFFF5C542);
  static const goldBright = Color(0xFFFFE08A);
  static const cream = Color(0xFFF7F1E3);
  static const danger = Color(0xFFE24B4B);
  static const dockFill = Color(0xCC15202E);
  static const voidNavy = Color(0xFF1C2436);
  static const deepIndigo = Color(0xFF2A3348);
  static const pill = Color(0xCC0F1722);
}

enum HomeTab { home, games, achievements, friends, allApps }

class HomeDeckMetrics {
  const HomeDeckMetrics({
    required this.size,
    required this.scale,
    required this.columns,
    required this.rows,
    required this.gap,
    required this.padding,
  });

  factory HomeDeckMetrics.of(Size size) {
    final scale = (size.shortestSide / 800).clamp(0.72, 2.2);
    return HomeDeckMetrics(
      size: size,
      scale: scale,
      columns: 8,
      rows: 3,
      gap: 8 * scale,
      padding: 28 * scale,
    );
  }

  final Size size;
  final double scale;
  final int columns;
  final int rows;
  final double gap;
  final double padding;

  int get pageSize => columns * rows;

  double get titleSize => 18 * scale;
  double get tileNameSize => 13 * scale;
  double get hintSize => 12 * scale;
  double get dockSize => 42 * scale;
}

ThemeData homeDeckTheme() {
  const scheme = ColorScheme.dark(
    primary: HomeDeckColors.cyan,
    onPrimary: Color(0xFF08202A),
    secondary: HomeDeckColors.cyanDeep,
    surface: HomeDeckColors.canvas,
    onSurface: HomeDeckColors.ink,
    error: HomeDeckColors.danger,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: HomeDeckColors.canvasDeep,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: HomeDeckColors.ink,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: HomeDeckColors.ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: HomeDeckColors.ink),
      bodyMedium: TextStyle(color: HomeDeckColors.muted),
    ),
  );
}

/// Official HomeDeck mark. The PNG is Tre's artwork and is not modified.
class HomeDeckMark extends StatelessWidget {
  const HomeDeckMark({super.key, this.size = 48});

  static const assetPath = 'assets/branding/homedeck-icon.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: 'HomeDeck',
    );
  }
}
