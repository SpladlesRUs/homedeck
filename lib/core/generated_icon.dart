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

String initialFor(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) {
    return 'H';
  }
  return trimmed.substring(0, 1).toUpperCase();
}

/// Draws a cached 256px tile: rounded color field plus the app initial.
///
/// Used whenever Windows PE/.lnk icon extraction is unavailable (see
/// docs/DECISIONS.md).
Future<Uint8List> generateInitialIcon({
  required String displayName,
  required String key,
  int size = 256,
}) async {
  final color = colorForKey(key);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Offset.zero & Size(size.toDouble(), size.toDouble());
  final radius = Radius.circular(size * 0.18);
  final rrect = RRect.fromRectAndRadius(rect.deflate(size * 0.04), radius);

  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, radius),
    Paint()..color = const Color(0xFF0B1026),
  );
  canvas.drawRRect(rrect, Paint()..color = color);

  final highlight = Paint()
    ..shader = ui.Gradient.linear(
      Offset(size * 0.2, size * 0.1),
      Offset(size * 0.8, size * 0.9),
      [
        const Color(0x66FFFFFF),
        const Color(0x00000000),
      ],
    );
  canvas.drawRRect(rrect, highlight);

  final paragraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.center,
    fontWeight: FontWeight.w800,
    fontSize: size * 0.46,
  );
  final builder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(
      ui.TextStyle(
        color: const Color(0xFFF7F1E3),
        fontSize: size * 0.46,
        fontWeight: FontWeight.w800,
      ),
    )
    ..addText(initialFor(displayName));
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: size.toDouble()));
  canvas.drawParagraph(
    paragraph,
    Offset(0, (size - paragraph.height) / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Failed to encode generated HomeDeck icon');
  }
  return bytes.buffer.asUint8List();
}
