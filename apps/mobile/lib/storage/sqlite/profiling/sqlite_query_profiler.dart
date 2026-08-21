import 'dart:developer';
import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Debug/profile instrumentation for local SQLite I/O.
abstract final class SqliteQueryProfiler {
  SqliteQueryProfiler._();

  /// Overrides [enabled] in tests.
  @visibleForTesting
  static bool? enabledOverride;

  /// When true, profiling wrappers decorate sqflite handles.
  static bool get enabled {
    if (enabledOverride != null) {
      return enabledOverride!;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    return !kReleaseMode;
  }

  static const _sqlPreviewLength = 120;

  /// Collapses whitespace and truncates SQL for logs and Timeline args.
  static String previewSql(String sql) {
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= _sqlPreviewLength) {
      return normalized;
    }
    return '${normalized.substring(0, _sqlPreviewLength)}…';
  }

  static String tableLabel(String kind, String table) => '$kind $table';

  static Future<T> profileAsync<T>({
    required String kind,
    required String label,
    required Future<T> Function() action,
    Map<String, Object?> timelineArgs = const {},
  }) async {
    if (!enabled) {
      return action();
    }

    final stopwatch = Stopwatch()..start();
    final task = TimelineTask()
      ..start('sqlite:$kind', arguments: {
        'label': label,
        ...timelineArgs,
      });
    try {
      final result = await action();
      _finishProfile(
        kind: kind,
        label: label,
        elapsedMs: stopwatch.elapsedMilliseconds,
        task: task,
      );
      return result;
    } on Object catch (error, stackTrace) {
      _finishProfile(
        kind: kind,
        label: label,
        elapsedMs: stopwatch.elapsedMilliseconds,
        task: task,
        error: error,
      );
      rethrow;
    }
  }

  static void _finishProfile({
    required String kind,
    required String label,
    required int elapsedMs,
    required TimelineTask task,
    Object? error,
  }) {
    stopwatchSafeFinish(task);
    final status = error == null ? 'ok' : 'error';
    AppLogger.debug('SQLITE [$kind] ${elapsedMs}ms ($status) — $label');
  }
}

void stopwatchSafeFinish(TimelineTask task) {
  try {
    task.finish();
  } on Object {
    // Timeline finish is best-effort in tests and profile tooling.
  }
}