import 'package:flutter/widgets.dart';

/// Sparse desktop-style Home grid. Null slots stay empty; unpinning does
/// not compact neighbors.
class HomeLayout {
  const HomeLayout({this.slots = const []});

  final List<String?> slots;

  int get length => slots.length;

  String? operator [](int index) {
    if (index < 0 || index >= slots.length) {
      return null;
    }
    return slots[index];
  }

  List<String?> padded(int minLength) {
    if (minLength <= slots.length) {
      return slots;
    }
    return [...slots, ...List<String?>.filled(minLength - slots.length, null)];
  }

  bool contains(String id) => slots.contains(id);

  int? indexOf(String id) {
    final index = slots.indexOf(id);
    return index < 0 ? null : index;
  }

  int get lastOccupiedIndex {
    for (var i = slots.length - 1; i >= 0; i--) {
      if (slots[i] != null) {
        return i;
      }
    }
    return -1;
  }

  HomeLayout pinning(String id, {int? at}) {
    final next = List<String?>.from(slots);
    for (var i = 0; i < next.length; i++) {
      if (next[i] == id) {
        next[i] = null;
      }
    }
    var slot = at;
    if (slot == null) {
      slot = next.indexWhere((value) => value == null);
      if (slot < 0) {
        slot = next.length;
      }
    }
    while (next.length <= slot) {
      next.add(null);
    }
    next[slot] = id;
    return HomeLayout(slots: List<String?>.unmodifiable(next));
  }

  HomeLayout unpinning(String id) {
    if (!contains(id)) {
      return this;
    }
    final next = [
      for (final value in slots) value == id ? null : value,
    ];
    return HomeLayout(slots: List<String?>.unmodifiable(next));
  }

  HomeLayout swapping(int from, int to) {
    if (from < 0 || to < 0 || from == to) {
      return this;
    }
    final maxIndex = from > to ? from : to;
    final next = padded(maxIndex + 1).toList();
    final stored = next[from];
    next[from] = next[to];
    next[to] = stored;
    return HomeLayout(slots: List<String?>.unmodifiable(next));
  }

  HomeLayout moving(int from, TraversalDirection direction, int columns) {
    if (from < 0 || columns <= 0) {
      return this;
    }
    final to = switch (direction) {
      TraversalDirection.left => from - 1,
      TraversalDirection.right => from + 1,
      TraversalDirection.up => from - columns,
      TraversalDirection.down => from + columns,
    };
    if (to < 0) {
      return this;
    }
    return swapping(from, to);
  }

  Map<String, Object?> toJson() => {'slots': slots};

  factory HomeLayout.fromJson(Map<String, Object?> json) {
    final raw = json['slots'];
    if (raw is! List) {
      return const HomeLayout();
    }
    return HomeLayout(
      slots: List<String?>.unmodifiable([
        for (final entry in raw) entry == null ? null : '$entry',
      ]),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeLayout && _nullableEquals(other.slots, slots);
  }

  @override
  int get hashCode => Object.hashAll(slots);
}

bool _nullableEquals(List<String?> a, List<String?> b) {
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
