import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Palette used when an executable icon cannot be extracted.
const generatedTileColors = <Color>[
  Color(0xFFE94F37),
  Color(0xFFF5A623),
  Color(0xFF2EC4B6),
  Color(0xFF4DA3FF),
  Color(0xFF7B61FF),
  Color(0xFFFF6B6B),
  Color(0xFF3DDC97),
  Color(0xFFFF8C42),
  Color(0xFF5B8DEF),
  Color(0xFFC26DF5),
];

Color colorForKey(String key) {
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = 0x1fffffff & (hash + unit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  final index = hash.abs() % generatedTileColors.length;
  return generatedTileColors[index];
}

int hashForKey(String key) {
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = 0x1fffffff & (hash + unit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  return hash.abs();
}

String initialFor(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) {
    return 'H';
  }
  return trimmed.substring(0, 1).toUpperCase();
}

/// Original full-bleed tile art. Geometric scenes only — no licensed characters.
Future<Uint8List> generateInitialIcon({
  required String displayName,
  required String key,
  int size = 256,
}) async {
  final color = colorForKey(key);
  final style = hashForKey(key) % 8;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Offset.zero & Size(size.toDouble(), size.toDouble());
  final s = size.toDouble();

  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(s, s),
        [_shift(color, 0.18), _shift(color, -0.22)],
      ),
  );

  switch (style) {
    case 0:
      _rings(canvas, s, color);
    case 1:
      _hills(canvas, s, color);
    case 2:
      _stripes(canvas, s);
    case 3:
      _stars(canvas, s, key);
    case 4:
      _waves(canvas, s, color);
    case 5:
      _diamonds(canvas, s);
    case 6:
      _blobs(canvas, s, color);
    default:
      _sunburst(canvas, s);
  }

  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(s * 0.2, 0),
        Offset(s * 0.8, s),
        const [Color(0x55FFFFFF), Color(0x00000000)],
      ),
  );

  final paragraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.center,
    fontWeight: FontWeight.w800,
    fontSize: s * 0.42,
  );
  final builder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(
      ui.TextStyle(
        color: const Color(0xF2FFFFFF),
        fontSize: s * 0.42,
        fontWeight: FontWeight.w800,
      ),
    )
    ..addText(initialFor(displayName));
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: s));
  canvas.drawParagraph(paragraph, Offset(0, (s - paragraph.height) / 2));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Failed to encode generated HomeDeck icon');
  }
  return bytes.buffer.asUint8List();
}

Color _shift(Color color, double amount) {
  final h = HSVColor.fromColor(color);
  return h
      .withValue((h.value + amount).clamp(0.15, 1.0))
      .withSaturation((h.saturation - amount.abs() * 0.1).clamp(0.2, 1.0))
      .toColor();
}

void _rings(Canvas canvas, double s, Color color) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.045
    ..color = const Color(0x66FFFFFF);
  for (var i = 1; i <= 5; i++) {
    canvas.drawCircle(Offset(s * 0.62, s * 0.38), s * 0.12 * i, paint);
  }
}

void _hills(Canvas canvas, double s, Color color) {
  final path = Path()
    ..moveTo(0, s)
    ..quadraticBezierTo(s * 0.25, s * 0.45, s * 0.55, s * 0.7)
    ..quadraticBezierTo(s * 0.8, s * 0.9, s, s * 0.55)
    ..lineTo(s, s)
    ..close();
  canvas.drawPath(path, Paint()..color = const Color(0x33000000));
  canvas.drawCircle(
    Offset(s * 0.78, s * 0.22),
    s * 0.14,
    Paint()..color = const Color(0x88FFFFFF),
  );
}

void _stripes(Canvas canvas, double s) {
  final paint = Paint()..color = const Color(0x22FFFFFF);
  canvas.save();
  canvas.translate(s * 0.5, s * 0.5);
  canvas.rotate(-0.4);
  for (var i = -6; i <= 6; i++) {
    canvas.drawRect(
      Rect.fromLTWH(i * s * 0.14, -s, s * 0.07, s * 2),
      paint,
    );
  }
  canvas.restore();
}

void _stars(Canvas canvas, double s, String key) {
  final rnd = math.Random(hashForKey(key));
  final paint = Paint()..color = const Color(0xCCFFFFFF);
  for (var i = 0; i < 18; i++) {
    canvas.drawCircle(
      Offset(rnd.nextDouble() * s, rnd.nextDouble() * s * 0.7),
      1.5 + rnd.nextDouble() * 3,
      paint,
    );
  }
  canvas.drawCircle(
    Offset(s * 0.72, s * 0.22),
    s * 0.11,
    Paint()..color = const Color(0xAAFFF6C8),
  );
}

void _waves(Canvas canvas, double s, Color color) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.04
    ..color = const Color(0x55FFFFFF);
  for (var row = 0; row < 6; row++) {
    final path = Path();
    final y = s * (0.25 + row * 0.12);
    path.moveTo(0, y);
    for (var x = 0.0; x <= s; x += s * 0.1) {
      path.quadraticBezierTo(
        x + s * 0.05,
        y + (row.isEven ? -s * 0.04 : s * 0.04),
        x + s * 0.1,
        y,
      );
    }
    canvas.drawPath(path, paint);
  }
}

void _diamonds(Canvas canvas, double s) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.025
    ..color = const Color(0x55FFFFFF);
  for (var i = 1; i <= 4; i++) {
    final d = s * 0.12 * i;
    canvas.save();
    canvas.translate(s * 0.5, s * 0.5);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: d * 2, height: d * 2), paint);
    canvas.restore();
  }
}

void _blobs(Canvas canvas, double s, Color color) {
  canvas.drawCircle(
    Offset(s * 0.3, s * 0.35),
    s * 0.28,
    Paint()..color = const Color(0x33FFFFFF),
  );
  canvas.drawCircle(
    Offset(s * 0.72, s * 0.68),
    s * 0.24,
    Paint()..color = const Color(0x22000000),
  );
}

void _sunburst(Canvas canvas, double s) {
  final paint = Paint()..color = const Color(0x22FFFFFF);
  canvas.save();
  canvas.translate(s * 0.5, s * 0.5);
  for (var i = 0; i < 12; i++) {
    canvas.drawRect(Rect.fromLTWH(-s * 0.03, 0, s * 0.06, s * 0.55), paint);
    canvas.rotate(math.pi / 6);
  }
  canvas.restore();
}
