import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/ui_clicks.dart';

void main() {
  test('synthesized ticks are short PCM WAV files', () {
    final wav = tickWavForTest(920);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, greaterThan(44));
  });

  test('disabled player never needs a plugin', () async {
    final player = UiClickPlayer(enabled: false);
    await player.play(UiClick.move);
    await player.dispose();
  });
}
