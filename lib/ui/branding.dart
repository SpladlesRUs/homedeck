import 'package:material_ui/material_ui.dart';

/// Original HomeDeck palette. Inspired by living-room consoles, not Nintendo.
class HomeDeckColors {
  static const canvas = Color(0xFFF4F6F9);
  static const canvasDeep = Color(0xFFD5DCE6);
  static const pattern = Color(0xFFC9D1DC);
  static const tileFrame = Color(0xFFFFFFFF);
  static const tileEmpty = Color(0xFFE6EAEF);
  static const tileEmptyEdge = Color(0xFFD0D6DE);
  static const ink = Color(0xFF3B4354);
  static const muted = Color(0xFF7B8494);
  static const cyan = Color(0xFF2EC4FF);
  static const cyanDeep = Color(0xFF1289D4);
  static const gold = Color(0xFFF5C542);
  static const goldBright = Color(0xFFFFE08A);
  static const cream = Color(0xFFF7F1E3);
  static const danger = Color(0xFFE24B4B);
  static const dockFill = Color(0xFFFBFCFD);
  static const voidNavy = Color(0xFF1C2436);
  static const deepIndigo = Color(0xFF2A3348);
}

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
    final columns = size.width >= 2560
        ? 7
        : size.width >= 1760
        ? 6
        : 5;
    final rows = size.height >= 1080 ? 4 : 3;
    final scale = (size.shortestSide / 800).clamp(0.72, 2.2);
    return HomeDeckMetrics(
      size: size,
      scale: scale,
      columns: columns,
      rows: rows,
      gap: 14 * scale,
      padding: 40 * scale,
    );
  }

  final Size size;
  final double scale;
  final int columns;
  final int rows;
  final double gap;
  final double padding;

  int get pageSize => columns * rows;

  double get titleSize => 22 * scale;
  double get tileNameSize => 13 * scale;
  double get hintSize => 12 * scale;
  double get dockSize => 58 * scale;
}

ThemeData homeDeckTheme() {
  const scheme = ColorScheme.light(
    primary: HomeDeckColors.cyan,
    onPrimary: Colors.white,
    secondary: HomeDeckColors.cyanDeep,
    surface: HomeDeckColors.canvas,
    onSurface: HomeDeckColors.ink,
    error: HomeDeckColors.danger,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: HomeDeckColors.canvas,
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
