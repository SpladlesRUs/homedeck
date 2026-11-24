import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';

/// Shared library entry. Stable [id] is HomeDeck's identifier; launch
/// locations live per-platform in [targets] and are not portable.
class AppRecord {
  const AppRecord({
    required this.id,
    required this.displayName,
    required this.position,
    this.iconRef,
    this.category,
    this.favorite = false,
    this.targets = const {},
  });

  /// Stable HomeDeck UUID. Never derived from a filesystem path.
  final String id;

  final String displayName;

  /// Path relative to HomeDeck's application support directory, or null
  /// when no cached icon exists yet.
  final String? iconRef;

  /// Index in the persisted tile layout. [TileLayout.orderedIds] is the
  /// source of truth when both are present.
  final int position;

  final String? category;

  final bool favorite;

  final Map<AppPlatform, LaunchTarget> targets;

  LaunchTarget? targetFor(AppPlatform platform) => targets[platform];

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'iconRef': iconRef,
    'position': position,
    'category': category,
    'favorite': favorite,
    'targets': {
      for (final entry in targets.entries) entry.key.wireName: entry.value.toJson(),
    },
  };

  factory AppRecord.fromJson(Map<String, Object?> json) {
    final rawTargets = json['targets'];
    final targets = <AppPlatform, LaunchTarget>{};
    if (rawTargets is Map) {
      rawTargets.forEach((key, value) {
        if (value is Map) {
          final platform = AppPlatform.fromWire('$key');
          targets[platform] = LaunchTarget.fromJson(
            value.map((k, v) => MapEntry('$k', v)),
          );
        }
      });
    }
    return AppRecord(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      iconRef: json['iconRef'] as String?,
      position: json['position'] as int? ?? 0,
      category: json['category'] as String?,
      favorite: json['favorite'] as bool? ?? false,
      targets: Map<AppPlatform, LaunchTarget>.unmodifiable(targets),
    );
  }

  AppRecord copyWith({
    String? id,
    String? displayName,
    String? iconRef,
    bool clearIconRef = false,
    int? position,
    String? category,
    bool clearCategory = false,
    bool? favorite,
    Map<AppPlatform, LaunchTarget>? targets,
  }) {
    return AppRecord(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      iconRef: clearIconRef ? null : (iconRef ?? this.iconRef),
      position: position ?? this.position,
      category: clearCategory ? null : (category ?? this.category),
      favorite: favorite ?? this.favorite,
      targets: targets ?? this.targets,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppRecord &&
        other.id == id &&
        other.displayName == displayName &&
        other.iconRef == iconRef &&
        other.position == position &&
        other.category == category &&
        other.favorite == favorite &&
        _targetMapsEqual(other.targets, targets);
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    iconRef,
    position,
    category,
    favorite,
    Object.hashAll(
      targets.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

bool _targetMapsEqual(
  Map<AppPlatform, LaunchTarget> a,
  Map<AppPlatform, LaunchTarget> b,
) {
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
