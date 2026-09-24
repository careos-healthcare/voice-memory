import 'dart:async';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_hybrid_search_initializer.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Holds sqlite-vec loading and embedding-index checks until the first
/// interactive frame. Database open stays on the startup path; this work does not.
abstract final class ColdStartDeferredWork {
  ColdStartDeferredWork._();

  static final List<Future<void> Function()> _tasks = [];
  static Future<void>? _inFlight;
  static var _started = false;
  static var _finished = false;

  /// Queues [task] until [run], or starts it immediately once startup has passed.
  static void defer(Future<void> Function() task) {
    if (_started) {
      unawaited(_guard(task));
      return;
    }
    _tasks.add(task);
  }

  /// Schedules sqlite-vec extension load and embedding index checks for [db].
  static void deferHybridSearch(Database db) {
    defer(() => SqliteHybridSearchInitializer.initialize(db));
  }

  /// Runs queued work once. Later calls are no-ops.
  static Future<void> run() {
    if (_finished) return Future<void>.value();
    _started = true;
    return _inFlight ??= _drain();
  }

  static Future<void> _drain() async {
    final tasks = List<Future<void> Function()>.of(_tasks);
    _tasks.clear();
    for (final task in tasks) {
      await _guard(task);
    }
    _finished = true;
  }

  static Future<void> _guard(Future<void> Function() task) async {
    try {
      await task();
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Deferred cold-start work skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _tasks.clear();
    _inFlight = null;
    _started = false;
    _finished = false;
  }

  @visibleForTesting
  static int get pendingCount => _tasks.length;

  @visibleForTesting
  static bool get hasStarted => _started;
}
