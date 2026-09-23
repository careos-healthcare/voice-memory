import 'dart:io';
import 'dart:math' as math;

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// One background job the diagnostics screen can show.
class DiagnosticTaskStatus {
  const DiagnosticTaskStatus({required this.name, required this.detail});

  final String name;
  final String detail;
}

/// Result of `PRAGMA quick_check` and the sqlite-vec index check.
class DatabaseHealthReport {
  const DatabaseHealthReport({
    required this.healthy,
    required this.quickCheckOk,
    required this.vecConsistent,
    this.recovered = false,
    this.restoredFrom,
  });

  const DatabaseHealthReport.failed()
    : healthy = false,
      quickCheckOk = false,
      vecConsistent = false,
      recovered = false,
      restoredFrom = null;

  final bool healthy;
  final bool quickCheckOk;
  final bool vecConsistent;
  final bool recovered;
  final String? restoredFrom;
}

/// What the system-health screen renders.
class DatabaseDiagnosticsSnapshot {
  const DatabaseDiagnosticsSnapshot({
    required this.vectorFootprintBytes,
    required this.quantizationBits,
    required this.fileSizeBytes,
    required this.connectionOpen,
    required this.schemaVersion,
    required this.migrationHistory,
    required this.tasks,
  });

  final int vectorFootprintBytes;
  final int quantizationBits;
  final int fileSizeBytes;
  final bool connectionOpen;
  final int schemaVersion;

  /// Applied versions from 1 through 20.
  final List<int> migrationHistory;
  final List<DiagnosticTaskStatus> tasks;

  String get footprintLabel => formatByteSize(vectorFootprintBytes);

  String get fileSizeLabel => formatByteSize(fileSizeBytes);

  String get historyLabel {
    if (migrationHistory.isEmpty) return 'No migrations applied';
    return 'Versions ${migrationHistory.first}-${migrationHistory.last}';
  }
}

/// Local backups, integrity checks, and disk cleanup for the archive database.
class DatabaseHealthService {
  static const newestBackupName = 'archive_me_backup_1.db';
  static const previousBackupName = 'archive_me_backup_2.db';

  static const backupNames = <String>[newestBackupName, previousBackupName];

  static DatabaseHealthReport? lastReport;

  /// Copies [databaseFile] into the two rolling backup slots.
  ///
  /// The newest copy is [newestBackupName]. The previous newest copy moves
  /// to [previousBackupName]. Call this before a schema migration or a full
  /// vector quantization rebuild.
  Future<void> retainRollingBackup(File databaseFile) async {
    if (_skip(databaseFile)) return;
    final newest = File(p.join(databaseFile.parent.path, newestBackupName));
    final previous = File(p.join(databaseFile.parent.path, previousBackupName));
    if (newest.existsSync() && !_sameFile(newest, databaseFile)) {
      newest.copySync(previous.path);
    }
    if (_sameFile(databaseFile, newest)) return;
    databaseFile.copySync(newest.path);
  }

  /// Runs `PRAGMA quick_check` and, when sqlite-vec is loaded, counts `vec_chunks`.
  Future<DatabaseHealthReport> checkOpen(
    Database database, {
    bool vecExtensionLoaded = false,
  }) async {
    final quickOk = await _quickCheckOk(database);
    final vecOk = await _vecConsistent(
      database,
      extensionLoaded: vecExtensionLoaded,
    );
    final report = DatabaseHealthReport(
      healthy: quickOk && vecOk,
      quickCheckOk: quickOk,
      vecConsistent: vecOk,
    );
    lastReport = report;
    return report;
  }

  /// Checks [databasePath] and, when the index is corrupt, restores a backup.
  Future<DatabaseHealthReport> runStartupCheck({
    required String databasePath,
    required Future<Database> Function(String path) openDatabase,
    bool vecExtensionLoaded = false,
  }) async {
    final live = File(databasePath);
    if (_skip(live)) {
      return const DatabaseHealthReport(
        healthy: true,
        quickCheckOk: true,
        vecConsistent: true,
      );
    }
    final opened = await _checkFile(
      live,
      openDatabase: openDatabase,
      vecExtensionLoaded: vecExtensionLoaded,
    );
    if (opened.healthy) {
      lastReport = opened;
      return opened;
    }
    for (final name in backupNames) {
      final backup = File(p.join(live.parent.path, name));
      if (!backup.existsSync()) continue;
      final valid = await _checkFile(
        backup,
        openDatabase: openDatabase,
        vecExtensionLoaded: false,
      );
      if (!valid.quickCheckOk) continue;
      backup.copySync(live.path);
      final restored = DatabaseHealthReport(
        healthy: true,
        quickCheckOk: true,
        vecConsistent: valid.vecConsistent,
        recovered: true,
        restoredFrom: name,
      );
      lastReport = restored;
      return restored;
    }
    lastReport = opened;
    return opened;
  }

  /// Compacts the database, rebuilds indexes, and deletes `*.tmp` files.
  Future<int> vacuumAndReindex({
    required Database database,
    Directory? scratchDirectory,
  }) async {
    await database.execute('VACUUM');
    await database.execute('REINDEX');
    return _deleteOrphanTemps(scratchDirectory);
  }

  static List<int> migrationHistoryThrough20(int schemaVersion) {
    final last = math.min(math.max(schemaVersion, 0), 20);
    return [for (var version = 1; version <= last; version++) version];
  }

  static List<DiagnosticTaskStatus> backgroundTasks({
    bool? lifeMemoEnabled,
    bool? meshEnabled,
  }) {
    final memo = lifeMemoEnabled ?? V1CapabilityRegistry.backgroundProcessing;
    final mesh = meshEnabled ?? V1CapabilityRegistry.p2pAndWebRtc;
    return [
      DiagnosticTaskStatus(
        name: 'Sunday life memo',
        detail: memo
            ? 'Scheduled for Sunday at 20:00.'
            : 'Not scheduled on this device.',
      ),
      DiagnosticTaskStatus(
        name: 'Mesh sync',
        detail: mesh
            ? 'Discovery is on.'
            : 'Mesh discovery is off on this device.',
      ),
    ];
  }

  Future<int> readSchemaVersion(Database database) async {
    final rows = await database.rawQuery('PRAGMA user_version');
    if (rows.isEmpty) return 0;
    final value = rows.first['user_version'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  bool _skip(File file) {
    final name = p.basename(file.path);
    if (name == ':memory:' || name.isEmpty) return true;
    return !file.existsSync();
  }

  bool _sameFile(File left, File right) => p.normalize(left.path) == p.normalize(right.path);

  Future<DatabaseHealthReport> _checkFile(
    File file, {
    required Future<Database> Function(String path) openDatabase,
    required bool vecExtensionLoaded,
  }) async {
    try {
      final database = await openDatabase(file.path);
      try {
        return await checkOpen(
          database,
          vecExtensionLoaded: vecExtensionLoaded,
        );
      } finally {
        await database.close();
      }
    } on Object {
      return const DatabaseHealthReport.failed();
    }
  }

  Future<bool> _quickCheckOk(Database database) async {
    try {
      final rows = await database.rawQuery('PRAGMA quick_check');
      if (rows.isEmpty) return false;
      return rows.every((row) {
        final value = row.values.isEmpty ? null : row.values.first;
        return value == 'ok';
      });
    } on Object {
      return false;
    }
  }

  Future<bool> _vecConsistent(
    DatabaseExecutor database, {
    required bool extensionLoaded,
  }) async {
    if (!extensionLoaded) return true;
    try {
      await database.rawQuery('SELECT COUNT(*) AS n FROM vec_chunks');
      return true;
    } on Object {
      return false;
    }
  }

  int _deleteOrphanTemps(Directory? directory) {
    if (directory == null || !directory.existsSync()) return 0;
    var removed = 0;
    for (final entity in directory.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.tmp')) continue;
      entity.deleteSync();
      removed += 1;
    }
    return removed;
  }
}

String formatByteSize(int bytes) {
  if (bytes >= 1024 * 1024 && bytes % (1024 * 1024) == 0) {
    return '${bytes ~/ (1024 * 1024)} MB';
  }
  if (bytes >= 1024 && bytes % 1024 == 0) {
    return '${bytes ~/ 1024} KB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
