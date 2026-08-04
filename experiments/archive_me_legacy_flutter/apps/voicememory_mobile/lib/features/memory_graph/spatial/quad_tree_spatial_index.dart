import 'package:flutter/widgets.dart';

@immutable
final class SpatialIndexEntry<T> {
  const SpatialIndexEntry({required this.bounds, required this.value});

  final Rect bounds;
  final T value;
}

/// A bounded quadtree for viewport and hit-test queries.
///
/// Entries spanning more than one child quadrant remain in their parent,
/// preventing duplicates while preserving O(log N + K) point/rect lookups.
final class QuadTreeSpatialIndex<T> {
  QuadTreeSpatialIndex({
    required Rect bounds,
    this.nodeCapacity = 12,
    this.maxDepth = 12,
  }) : assert(nodeCapacity > 0),
       assert(maxDepth > 0),
       _root = _QuadTreeNode<T>(_validated(bounds), depth: 0);

  final int nodeCapacity;
  final int maxDepth;
  final _QuadTreeNode<T> _root;
  int _length = 0;

  Rect get bounds => _root.bounds;
  int get length => _length;
  bool get isEmpty => _length == 0;

  bool insert(Rect bounds, T value) {
    final normalized = _validated(bounds);
    if (!_root.bounds.overlaps(normalized) &&
        !_root.bounds.contains(normalized.topLeft)) {
      return false;
    }
    _root.insert(
      SpatialIndexEntry(bounds: normalized, value: value),
      capacity: nodeCapacity,
      maxDepth: maxDepth,
    );
    _length++;
    return true;
  }

  List<T> query(Rect area) {
    final normalized = _validated(area);
    if (!_root.bounds.overlaps(normalized) &&
        !_root.bounds.contains(normalized.topLeft)) {
      return const [];
    }
    final result = <T>[];
    _root.query(normalized, result);
    return result;
  }

  void clear() {
    _root.clear();
    _length = 0;
  }

  static Rect _validated(Rect value) {
    if (!value.left.isFinite ||
        !value.top.isFinite ||
        !value.right.isFinite ||
        !value.bottom.isFinite ||
        value.width < 0 ||
        value.height < 0) {
      throw ArgumentError.value(value, 'bounds', 'must be finite and ordered');
    }
    return value;
  }
}

final class _QuadTreeNode<T> {
  _QuadTreeNode(this.bounds, {required this.depth});

  final Rect bounds;
  final int depth;
  final List<SpatialIndexEntry<T>> entries = [];
  List<_QuadTreeNode<T>>? children;

  void insert(
    SpatialIndexEntry<T> entry, {
    required int capacity,
    required int maxDepth,
  }) {
    final target = _containingChild(entry.bounds);
    if (target != null) {
      target.insert(entry, capacity: capacity, maxDepth: maxDepth);
      return;
    }
    entries.add(entry);
    if (entries.length <= capacity || depth >= maxDepth) return;
    _subdivide();
    var index = entries.length - 1;
    while (index >= 0) {
      final child = _containingChild(entries[index].bounds);
      if (child != null) {
        final moved = entries.removeAt(index);
        child.insert(moved, capacity: capacity, maxDepth: maxDepth);
      }
      index--;
    }
  }

  void query(Rect area, List<T> result) {
    if (!bounds.overlaps(area) && !bounds.contains(area.topLeft)) return;
    for (final entry in entries) {
      if (entry.bounds.overlaps(area) ||
          area.contains(entry.bounds.topLeft) ||
          entry.bounds.contains(area.topLeft)) {
        result.add(entry.value);
      }
    }
    for (final child in children ?? <_QuadTreeNode<T>>[]) {
      child.query(area, result);
    }
  }

  void clear() {
    entries.clear();
    for (final child in children ?? <_QuadTreeNode<T>>[]) {
      child.clear();
    }
    children = null;
  }

  void _subdivide() {
    if (children != null || bounds.width == 0 || bounds.height == 0) return;
    final center = bounds.center;
    children = [
      _QuadTreeNode(
        Rect.fromLTRB(bounds.left, bounds.top, center.dx, center.dy),
        depth: depth + 1,
      ),
      _QuadTreeNode(
        Rect.fromLTRB(center.dx, bounds.top, bounds.right, center.dy),
        depth: depth + 1,
      ),
      _QuadTreeNode(
        Rect.fromLTRB(bounds.left, center.dy, center.dx, bounds.bottom),
        depth: depth + 1,
      ),
      _QuadTreeNode(
        Rect.fromLTRB(center.dx, center.dy, bounds.right, bounds.bottom),
        depth: depth + 1,
      ),
    ];
  }

  _QuadTreeNode<T>? _containingChild(Rect candidate) {
    final quadrants = children;
    if (quadrants == null) return null;
    for (final child in quadrants) {
      if (child.bounds.left <= candidate.left &&
          child.bounds.top <= candidate.top &&
          child.bounds.right >= candidate.right &&
          child.bounds.bottom >= candidate.bottom) {
        return child;
      }
    }
    return null;
  }
}
