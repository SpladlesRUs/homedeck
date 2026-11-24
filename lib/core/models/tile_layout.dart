import 'package:flutter/widgets.dart';

/// Persisted order of tiles on the home grid.
class TileLayout {
  const TileLayout({this.orderedIds = const []});

  final List<String> orderedIds;

  TileLayout placing(String id, {int? at}) {
    final next = List<String>.from(orderedIds)..remove(id);
    final index = (at ?? next.length).clamp(0, next.length);
    next.insert(index, id);
    return TileLayout(orderedIds: List<String>.unmodifiable(next));
  }

  TileLayout removing(String id) {
    return TileLayout(
      orderedIds: List<String>.unmodifiable(
        orderedIds.where((value) => value != id),
      ),
    );
  }

  TileLayout reordering(int from, int to) {
    if (from < 0 ||
        from >= orderedIds.length ||
        to < 0 ||
        to >= orderedIds.length ||
        from == to) {
      return this;
    }
    final next = List<String>.from(orderedIds);
    final item = next.removeAt(from);
    next.insert(to, item);
    return TileLayout(orderedIds: List<String>.unmodifiable(next));
  }

  /// Keyboard rearrange: swap the focused tile with its neighbor in [direction].
  TileLayout move(String id, TraversalDirection direction, int columns) {
    final index = orderedIds.indexOf(id);
    if (index < 0 || columns <= 0) {
      return this;
    }
    final targetIndex = switch (direction) {
      TraversalDirection.left => index - 1,
      TraversalDirection.right => index + 1,
      TraversalDirection.up => index - columns,
      TraversalDirection.down => index + columns,
    };
    if (targetIndex < 0 || targetIndex >= orderedIds.length) {
      return this;
    }
    return reordering(index, targetIndex);
  }

  Map<String, Object?> toJson() => {'orderedIds': orderedIds};

  factory TileLayout.fromJson(Map<String, Object?> json) {
    final raw = json['orderedIds'];
    final ids = raw is List
        ? raw.map((entry) => '$entry').toList(growable: false)
        : const <String>[];
    return TileLayout(orderedIds: List<String>.unmodifiable(ids));
  }

  @override
  bool operator ==(Object other) {
    return other is TileLayout && _listEquals(other.orderedIds, orderedIds);
  }

  @override
  int get hashCode => Object.hashAll(orderedIds);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
