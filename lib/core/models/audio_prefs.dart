/// Persisted menu-music settings. Modest default volume is Wii U-like.
class AudioPrefs {
  const AudioPrefs({
    this.musicEnabled = true,
    this.musicVolume = defaultMusicVolume,
    this.uiClicksEnabled = true,
  });

  static const defaultMusicVolume = 0.35;

  final bool musicEnabled;

  /// 0..1 linear volume. Clamped on parse.
  final double musicVolume;
  final bool uiClicksEnabled;

  AudioPrefs copyWith({
    bool? musicEnabled,
    double? musicVolume,
    bool? uiClicksEnabled,
  }) {
    return AudioPrefs(
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: (musicVolume ?? this.musicVolume).clamp(0.0, 1.0),
      uiClicksEnabled: uiClicksEnabled ?? this.uiClicksEnabled,
    );
  }

  Map<String, Object?> toJson() => {
    'musicEnabled': musicEnabled,
    'musicVolume': musicVolume,
    'uiClicksEnabled': uiClicksEnabled,
  };

  factory AudioPrefs.fromJson(Map<String, Object?> json) {
    final rawVolume = json['musicVolume'];
    final volume = rawVolume is num
        ? rawVolume.toDouble().clamp(0.0, 1.0)
        : defaultMusicVolume;
    return AudioPrefs(
      musicEnabled: json['musicEnabled'] as bool? ?? true,
      musicVolume: volume,
      uiClicksEnabled: json['uiClicksEnabled'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AudioPrefs &&
        other.musicEnabled == musicEnabled &&
        other.musicVolume == musicVolume &&
        other.uiClicksEnabled == uiClicksEnabled;
  }

  @override
  int get hashCode => Object.hash(musicEnabled, musicVolume, uiClicksEnabled);
}
