import 'package:material_ui/material_ui.dart';

/// Original HomeDeck palette. Not Nintendo's; readable from across a room.
class HomeDeckColors {
  static const voidNavy = Color(0xFF070B1A);
  static const deepIndigo = Color(0xFF121833);
  static const panel = Color(0xFF1B2347);
  static const gold = Color(0xFFF5C542);
  static const goldBright = Color(0xFFFFE08A);
  static const coral = Color(0xFFFF6B6B);
  static const teal = Color(0xFF2EC4B6);
  static const violet = Color(0xFF7B61FF);
  static const sky = Color(0xFF4DA3FF);
  static const cream = Color(0xFFF7F1E3);
  static const muted = Color(0xFF9AA3C7);
  static const danger = Color(0xFFFF5A5A);
}

class HomeDeckMetrics {
  const HomeDeckMetrics({
    required this.size,
    required this.scale,
    required this.columns,
    required this.gap,
    required this.padding,
  });

  factory HomeDeckMetrics.of(Size size) {
    final width = size.width;
    final columns = width >= 3000
        ? 8
        : width >= 1800
        ? 6
        : width >= 1400
        ? 5
        : 4;
    final scale = (size.shortestSide / 1080).clamp(0.72, 2.4);
    return HomeDeckMetrics(
      size: size,
      scale: scale,
      columns: columns,
      gap: 18 * scale,
      padding: 36 * scale,
    );
  }

  final Size size;
  final double scale;
  final int columns;
  final double gap;
  final double padding;

  double get titleSize => 42 * scale;
  double get tileNameSize => 20 * scale;
  double get hintSize => 16 * scale;
}

ThemeData homeDeckTheme() {
  const scheme = ColorScheme.dark(
    primary: HomeDeckColors.gold,
    onPrimary: HomeDeckColors.voidNavy,
    secondary: HomeDeckColors.teal,
    surface: HomeDeckColors.deepIndigo,
    onSurface: HomeDeckColors.cream,
    error: HomeDeckColors.danger,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: HomeDeckColors.voidNavy,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: HomeDeckColors.cream,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
      titleLarge: TextStyle(
        color: HomeDeckColors.cream,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: HomeDeckColors.cream),
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
