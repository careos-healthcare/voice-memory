import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Persisted native window frame for desktop relaunch.
class DesktopWindowState {
  const DesktopWindowState({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  static const defaultSize = Size(1180, 800);
  static const minimumSize = Size(900, 640);

  final double x;
  final double y;
  final double width;
  final double height;

  Size get size => Size(width, height);

  Rect get bounds => Rect.fromLTWH(x, y, width, height);

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  static DesktopWindowState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final width = _read(json['width']);
    final height = _read(json['height']);
    final x = _read(json['x']);
    final y = _read(json['y']);
    if (width == null || height == null || x == null || y == null) return null;
    if (width < minimumSize.width || height < minimumSize.height) return null;
    return DesktopWindowState(x: x, y: y, width: width, height: height);
  }

  static double? _read(Object? raw) {
    if (raw is num) return raw.toDouble();
    return null;
  }
}

/// JSON file store for [DesktopWindowState].
class DesktopWindowStateStore {
  DesktopWindowStateStore(this._file);

  final File _file;

  Future<DesktopWindowState?> load() async {
    if (!await _file.exists()) return null;
    try {
      final raw = jsonDecode(await _file.readAsString());
      if (raw is! Map) return null;
      return DesktopWindowState.fromJson(Map<String, dynamic>.from(raw));
    } on Object {
      return null;
    }
  }

  Future<void> save(DesktopWindowState state) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(state.toJson()));
  }
}
