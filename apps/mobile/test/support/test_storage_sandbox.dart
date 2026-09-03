import 'dart:io';

import 'package:archiveme_mobile/features/recording/recording_dependencies.dart'
    show AppServices;

import 'package:archiveme_mobile/services/app_services.dart' show AppServices;
import 'package:flutter_test/flutter_test.dart';

/// Fixed clock for deterministic test fixtures.
class TestClock {
  TestClock([DateTime? fixed]) : now = fixed ?? DateTime.utc(2026, 1, 15, 12);

  final DateTime now;
}

/// Monotonic test identifiers.
class TestIds {
  int _next = 0;

  String next([String prefix = 'test-id']) => '$prefix-${_next++}';
}

/// Isolated on-disk storage for a single Flutter test.
///
/// Owns a uniquely named directory under the system temp folder and exposes
/// absolute journal, preferences, recovery, and output paths. [AppServices.resetForTest]
/// accepts absolute paths verbatim, so each suite gets a private namespace with
/// no timestamped JSON files in the checkout.
class TestStorageSandbox {
  TestStorageSandbox._(this.root, {TestClock? clock, TestIds? ids})
    : clock = clock ?? TestClock(),
      ids = ids ?? TestIds();

  final Directory root;
  final TestClock clock;
  final TestIds ids;

  /// Creates a fresh sandbox directory. Call [dispose] in tearDown.
  static TestStorageSandbox create({
    String prefix = 'archiveme_test_',
    TestClock? clock,
    TestIds? ids,
  }) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    return TestStorageSandbox._(dir, clock: clock, ids: ids);
  }

  String get journalPath => _path('journal.json');

  String get prefsPath => _path('mobile_prefs.json');

  String get recoveryPath => _path('recovery');

  String get outputPath => _path('output');

  /// Resolves [relative] inside [root] or throws if it would escape.
  String path(String relative) => _path(relative);

  String _path(String relative) {
    if (relative.isEmpty ||
        relative.startsWith('/') ||
        relative.contains('..')) {
      throw ArgumentError.value(
        relative,
        'relative',
        'must be a simple relative path inside the sandbox',
      );
    }
    final resolved = '${root.path}/$relative';
    final normalizedRoot = _normalize(root.path);
    final normalizedResolved = _normalize(resolved);
    if (normalizedResolved != normalizedRoot &&
        !normalizedResolved.startsWith('$normalizedRoot/')) {
      throw ArgumentError.value(
        relative,
        'relative',
        'escapes sandbox root ${root.path}',
      );
    }
    return resolved;
  }

  static String _normalize(String path) {
    final segments = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isEmpty) {
          throw ArgumentError('path escapes root: $path');
        }
        segments.removeLast();
        continue;
      }
      segments.add(part);
    }
    return segments.isEmpty ? '/' : '/${segments.join('/')}';
  }

  Directory ensureDir(String relative) {
    final dir = Directory(path(relative));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Drains in-flight prefs writes for this sandbox, then deletes the directory.
  ///
  /// Fire-and-forget tracker writes are already on [MobilePrefsStore]'s mutex.
  /// Awaiting that mutex here (on the real event loop) closes the late-write
  /// race without hanging fake-async `testWidgets` tearDowns.
  Future<void> dispose() async {
    await _drainPrefsWritesForThisSandbox();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }

  Future<void> _drainPrefsWritesForThisSandbox() async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    final prefsPath = prefs.file.path;
    if (prefsPath != root.path && !prefsPath.startsWith('${root.path}/')) {
      return;
    }
    await TestWidgetsFlutterBinding.instance.runAsync(
      () => prefs.drainPendingWrites(),
    );
  }
}
