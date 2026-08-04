import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../services/local_storage/encrypted_sqlite_text_codec.dart';
import '../../services/local_storage/encrypted_audio_file_store.dart';
import 'transcription_job.dart';
import 'transcription_job_database.dart';

typedef TranscriptionDirectoryResolver = Future<Directory> Function();
typedef TranscriptionIdFactory = String Function();

/// Durable audio ownership and queue API for the transcription pipeline.
class TranscriptionLedger {
  TranscriptionLedger._({
    required this.database,
    required this.audioDirectory,
    required this._clock,
    required this._idFactory,
    required this.startupReconciliation,
    this.encryptedAudioStore,
  });

  final TranscriptionJobDatabase database;
  final Directory audioDirectory;
  final TranscriptionClock _clock;
  final TranscriptionIdFactory _idFactory;
  final EncryptedAudioFileStore? encryptedAudioStore;

  /// Repairs performed before [open] returned.
  final TranscriptionReconciliationResult startupReconciliation;

  static Future<TranscriptionLedger> open({
    String? databasePath,
    Directory? directory,
    Directory? audioDirectory,
    TranscriptionDirectoryResolver? directoryResolver,
    TranscriptionClock? clock,
    TranscriptionIdFactory? idFactory,
    TranscriptionTokenFactory? leaseTokenFactory,
    EncryptedSqliteTextCodec? textCodec,
    EncryptedAudioFileStore? encryptedAudioStore,
  }) async {
    if (directory != null && directoryResolver != null) {
      throw ArgumentError('Provide either directory or directoryResolver.');
    }
    final resolvedClock = clock ?? DateTime.now;
    final root =
        directory ??
        (databasePath == null
            ? await (directoryResolver ?? _defaultDirectory)()
            : File(databasePath).parent);
    final resolvedAudioDirectory =
        audioDirectory ?? Directory(path.join(root.path, 'audio'));
    await root.create(recursive: true);
    await resolvedAudioDirectory.create(recursive: true);
    await _purgeInterruptedAudioFiles(resolvedAudioDirectory);

    final database = TranscriptionJobDatabase.open(
      databasePath:
          databasePath ?? path.join(root.path, 'transcription_jobs.sqlite3'),
      clock: resolvedClock,
      tokenFactory: leaseTokenFactory,
      textCodec: textCodec,
    );
    try {
      final reconciliation = database.reconcile();
      return TranscriptionLedger._(
        database: database,
        audioDirectory: resolvedAudioDirectory,
        clock: resolvedClock,
        idFactory: idFactory ?? _randomId,
        startupReconciliation: reconciliation,
        encryptedAudioStore: encryptedAudioStore,
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Stream<List<TranscriptionJob>> get watchJobs => database.watchJobs;

  List<TranscriptionJob> get jobs => database.listJobs();

  TranscriptionJob? getJob(String id) => database.getJob(id);

  /// Copies [sourceAudio] into ledger-owned storage before recording the job.
  Future<TranscriptionJob> enqueue(
    File sourceAudio, {
    int durationSeconds = 0,
    String? entryId,
  }) async {
    final audioStore = encryptedAudioStore;
    if (!await sourceAudio.exists()) {
      throw ArgumentError.value(
        sourceAudio.path,
        'sourceAudio',
        'file does not exist',
      );
    }

    final id = _idFactory();
    if (id.isEmpty || database.getJob(id) != null) {
      throw StateError('Transcription job id is empty or already exists: $id');
    }
    final extension = audioStore == null
        ? _safeExtension(sourceAudio.path)
        : '${_safeExtension(sourceAudio.path)}.vault';
    final destination = File(path.join(audioDirectory.path, '$id$extension'));
    if (await destination.exists()) {
      throw StateError('Durable audio destination already exists for $id.');
    }

    if (audioStore == null) {
      await _durableCopy(
        source: sourceAudio,
        destination: destination,
        temporarySuffix: _randomId(),
      );
    } else {
      await audioStore.seal(sourceAudio, destination);
    }
    final now = _clock().toUtc();
    final job = TranscriptionJob(
      id: id,
      entryId: entryId ?? id,
      audioPath: destination.path,
      sourceFileName: path.basename(sourceAudio.path),
      durationSeconds: durationSeconds.clamp(0, 86400),
      status: TranscriptionJobStatus.queued,
      createdAt: now,
      updatedAt: now,
      attemptCount: 0,
    );
    try {
      database.insertJob(job);
      if (audioStore != null &&
          sourceAudio.path != destination.path &&
          await sourceAudio.exists()) {
        await _secureDelete(sourceAudio);
      }
      return job;
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  TranscriptionJob? acquireLease({
    Duration leaseDuration = const Duration(minutes: 5),
  }) => database.acquireLease(leaseDuration: leaseDuration);

  TranscriptionJob complete({
    required String id,
    required String leaseToken,
    required String transcript,
  }) =>
      database.complete(id: id, leaseToken: leaseToken, transcript: transcript);

  TranscriptionJob retry({
    required String id,
    required String leaseToken,
    required String error,
    Duration baseDelay = const Duration(seconds: 5),
    Duration maxDelay = const Duration(hours: 1),
    int maxAttempts = 5,
  }) => database.retry(
    id: id,
    leaseToken: leaseToken,
    error: error,
    baseDelay: baseDelay,
    maxDelay: maxDelay,
    maxAttempts: maxAttempts,
  );

  TranscriptionJob fail({
    required String id,
    required String leaseToken,
    required String error,
  }) => database.fail(id: id, leaseToken: leaseToken, error: error);

  TranscriptionJob cancel(String id, {String? leaseToken}) =>
      database.cancel(id, leaseToken: leaseToken);

  Future<void> cancelAndDeleteAudio(String id) async {
    final job = getJob(id);
    if (job == null || job.isTerminal) return;
    cancel(id, leaseToken: job.leaseToken);
    final audio = File(job.audioPath);
    if (await audio.exists()) await audio.delete();
  }

  Future<void> delete(String id, {bool deleteAudio = false}) async {
    final job = database.getJob(id);
    if (job == null) throw StateError('Transcription job not found: $id');
    database.deleteJob(id);
    if (deleteAudio) {
      final audio = File(job.audioPath);
      if (await audio.exists()) await audio.delete();
    }
  }

  /// Removes every queued job and its encrypted owned-audio object.
  Future<void> wipeAll() async {
    final jobs = database.listJobs();
    database.replaceAll(const []);
    for (final job in jobs) {
      final audio = File(job.audioPath);
      if (await audio.exists()) await audio.delete();
    }
    if (!await audioDirectory.exists()) return;
    await for (final entity in audioDirectory.list()) {
      if (entity is File && await entity.exists()) {
        await entity.delete();
      }
    }
  }

  void replaceAll(List<TranscriptionJob> jobs) => database.replaceAll(jobs);

  TranscriptionReconciliationResult reconcile() => database.reconcile();

  TranscriptionDatabaseIntegrity checkIntegrity() => database.checkIntegrity();

  void checkpoint() => database.checkpoint();

  File createDatabaseSnapshot(String destinationPath) =>
      database.createSnapshot(destinationPath);

  Future<void> close() => database.close();

  static Future<void> _durableCopy({
    required File source,
    required File destination,
    required String temporarySuffix,
  }) async {
    final temporary = File('${destination.path}.$temporarySuffix.tmp');
    RandomAccessFile? input;
    RandomAccessFile? output;
    try {
      input = await source.open(mode: FileMode.read);
      output = await temporary.open(mode: FileMode.write);
      const chunkSize = 256 * 1024;
      while (true) {
        final chunk = await input.read(chunkSize);
        if (chunk.isEmpty) break;
        await output.writeFrom(chunk);
      }
      await output.flush();
      await output.close();
      output = null;
      await input.close();
      input = null;
      await temporary.rename(destination.path);
    } catch (_) {
      await output?.close();
      await input?.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  static Future<void> _purgeInterruptedAudioFiles(Directory directory) async {
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      if (name.endsWith('.tmp') || name.contains('.working')) {
        await entity.delete();
      }
    }
  }

  static Future<void> _secureDelete(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    final handle = await file.open(mode: FileMode.write);
    try {
      const chunkSize = 64 * 1024;
      final zeroes = List<int>.filled(chunkSize, 0);
      var remaining = length;
      while (remaining > 0) {
        final count = remaining > chunkSize ? chunkSize : remaining;
        await handle.writeFrom(zeroes, 0, count);
        remaining -= count;
      }
      await handle.flush();
      await handle.truncate(0);
    } finally {
      await handle.close();
    }
    await file.delete();
  }

  static String _safeExtension(String sourcePath) {
    final extension = path.extension(sourcePath).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension)
        ? extension
        : '.audio';
  }

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'transcription_queue'));
  }

  static String _randomId() {
    final random = Random.secure();
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = random
        .nextInt(0x100000000)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'tx-$timestamp-$suffix';
  }
}
