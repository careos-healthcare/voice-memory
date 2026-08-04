import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_queue.dart';

void main() {
  late Directory temporaryDirectory;
  late _FakeClock clock;
  late int nextId;
  late int nextToken;
  final ledgers = <TranscriptionLedger>[];

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'transcription_ledger_',
    );
    clock = _FakeClock(DateTime.utc(2026, 7, 24, 12));
    nextId = 1;
    nextToken = 1;
  });

  tearDown(() async {
    for (final ledger in ledgers.reversed) {
      await ledger.close();
    }
    temporaryDirectory.deleteSync(recursive: true);
  });

  Future<TranscriptionLedger> openLedger({
    String? databasePath,
    Directory? directory,
  }) async {
    final ledger = await TranscriptionLedger.open(
      databasePath: databasePath,
      directory:
          directory ?? (databasePath == null ? temporaryDirectory : null),
      clock: clock.call,
      idFactory: () => 'job-${nextId++}',
      leaseTokenFactory: () => 'lease-${nextToken++}',
    );
    ledgers.add(ledger);
    return ledger;
  }

  Future<File> audio(String name, [List<int> bytes = const [1, 2, 3]]) async {
    final file = File('${temporaryDirectory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  test(
    'creates the current versioned schema and migrates version one',
    () async {
      final databasePath = '${temporaryDirectory.path}/legacy.sqlite3';
      final legacy = sqlite3.open(databasePath);
      legacy.execute('''
      CREATE TABLE transcription_jobs (
        id TEXT PRIMARY KEY NOT NULL,
        audio_path TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER,
        last_error TEXT,
        transcript TEXT,
        lease_token TEXT,
        lease_expires_at INTEGER
      )
    ''');
      legacy.execute(
        'INSERT INTO transcription_jobs '
        '(id, audio_path, status, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        ['legacy', '/tmp/legacy.m4a', 'completed', 1, 1],
      );
      legacy.userVersion = 1;
      legacy.close();

      final ledger = await openLedger(databasePath: databasePath);

      expect(
        ledger.database.schemaVersion,
        TranscriptionJobDatabase.currentSchemaVersion,
      );
      expect(ledger.getJob('legacy')!.sourceFileName, isEmpty);
      final inspection = sqlite3.open(databasePath);
      addTearDown(inspection.close);
      final columns = inspection
          .select('PRAGMA table_info(transcription_jobs)')
          .map((row) => row['name'])
          .toSet();
      expect(
        columns,
        containsAll(<String>{'source_file_name', 'completed_at'}),
      );
      expect(
        inspection
            .select("SELECT name FROM sqlite_master WHERE type = 'index'")
            .map((row) => row['name']),
        contains('transcription_jobs_lease_idx'),
      );
    },
  );

  test('enqueue durably copies audio before persisting a queued job', () async {
    final source = await audio('capture.m4a', [4, 5, 6, 7]);
    final ledger = await openLedger();

    final job = await ledger.enqueue(source);

    expect(job.id, 'job-1');
    expect(job.status, TranscriptionJobStatus.queued);
    expect(job.sourceFileName, 'capture.m4a');
    expect(job.audioPath, isNot(source.path));
    expect(await File(job.audioPath).readAsBytes(), [4, 5, 6, 7]);
    expect(ledger.getJob(job.id), job);
  });

  test('watch stream is broadcast and emits immutable snapshots', () async {
    final ledger = await openLedger();
    final first = <List<TranscriptionJob>>[];
    final second = <List<TranscriptionJob>>[];
    final firstSubscription = ledger.watchJobs.listen(first.add);
    final secondSubscription = ledger.watchJobs.listen(second.add);
    addTearDown(firstSubscription.cancel);
    addTearDown(secondSubscription.cancel);

    await ledger.enqueue(await audio('stream.m4a'));

    expect(ledger.watchJobs.isBroadcast, isTrue);
    expect(first.last.single.id, 'job-1');
    expect(second.last.single.id, 'job-1');
    expect(
      () => first.last.add(first.last.single),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('lease acquisition is exclusive and token-protected', () async {
    final ledger = await openLedger();
    await ledger.enqueue(await audio('lease.m4a'));

    final leased = ledger.acquireLease(
      leaseDuration: const Duration(minutes: 2),
    );

    expect(leased!.status, TranscriptionJobStatus.leased);
    expect(leased.leaseToken, 'lease-1');
    expect(leased.leaseExpiresAt, DateTime.utc(2026, 7, 24, 12, 2));
    expect(ledger.acquireLease(), isNull);
    expect(
      () => ledger.complete(
        id: leased.id,
        leaseToken: 'not-owner',
        transcript: 'no',
      ),
      throwsStateError,
    );
  });

  test('retry persists bounded exponential schedule and exhaustion', () async {
    final ledger = await openLedger();
    await ledger.enqueue(await audio('retry.m4a'));
    var leased = ledger.acquireLease()!;

    var retried = ledger.retry(
      id: leased.id,
      leaseToken: leased.leaseToken!,
      error: 'offline',
      baseDelay: const Duration(seconds: 10),
      maxAttempts: 3,
    );
    expect(retried.attemptCount, 1);
    expect(retried.status, TranscriptionJobStatus.retryWaiting);
    expect(retried.nextAttemptAt, clock.value.add(const Duration(seconds: 10)));
    expect(ledger.acquireLease(), isNull);

    clock.advance(const Duration(seconds: 10));
    leased = ledger.acquireLease()!;
    retried = ledger.retry(
      id: leased.id,
      leaseToken: leased.leaseToken!,
      error: 'busy',
      baseDelay: const Duration(seconds: 10),
      maxAttempts: 3,
    );
    expect(retried.attemptCount, 2);
    expect(retried.nextAttemptAt, clock.value.add(const Duration(seconds: 20)));

    clock.advance(const Duration(seconds: 20));
    leased = ledger.acquireLease()!;
    retried = ledger.retry(
      id: leased.id,
      leaseToken: leased.leaseToken!,
      error: 'still busy',
      baseDelay: const Duration(seconds: 10),
      maxAttempts: 3,
    );
    expect(retried.status, TranscriptionJobStatus.failed);
    expect(retried.attemptCount, 3);
    expect(retried.nextAttemptAt, isNull);
  });

  test('startup recovers expired leases and fails missing audio', () async {
    final databasePath = '${temporaryDirectory.path}/jobs.sqlite3';
    final audioDirectory = Directory('${temporaryDirectory.path}/owned_audio');
    final first = await TranscriptionLedger.open(
      databasePath: databasePath,
      audioDirectory: audioDirectory,
      clock: clock.call,
      idFactory: () => 'job-${nextId++}',
      leaseTokenFactory: () => 'lease-${nextToken++}',
    );
    ledgers.add(first);
    final expiredJob = await first.enqueue(await audio('expired.m4a'));
    first.acquireLease(leaseDuration: const Duration(seconds: 30));
    final missingJob = await first.enqueue(await audio('missing.m4a'));
    await File(missingJob.audioPath).delete();
    await first.close();
    ledgers.remove(first);
    clock.advance(const Duration(minutes: 1));

    final restarted = await TranscriptionLedger.open(
      databasePath: databasePath,
      audioDirectory: audioDirectory,
      clock: clock.call,
      idFactory: () => 'job-${nextId++}',
      leaseTokenFactory: () => 'lease-${nextToken++}',
    );
    ledgers.add(restarted);

    expect(restarted.startupReconciliation.expiredLeasesRecovered, 1);
    expect(restarted.startupReconciliation.missingAudioFailed, 1);
    expect(
      restarted.getJob(expiredJob.id)!.status,
      TranscriptionJobStatus.queued,
    );
    expect(
      restarted.getJob(missingJob.id)!.status,
      TranscriptionJobStatus.failed,
    );
    expect(restarted.getJob(missingJob.id)!.lastError, 'audio_file_missing');
  });

  test('completion persists transcript and clears lease metadata', () async {
    final ledger = await openLedger();
    await ledger.enqueue(await audio('complete.m4a'));
    final leased = ledger.acquireLease()!;

    final completed = ledger.complete(
      id: leased.id,
      leaseToken: leased.leaseToken!,
      transcript: 'A durable memory.',
    );

    expect(completed.status, TranscriptionJobStatus.completed);
    expect(completed.transcript, 'A durable memory.');
    expect(completed.completedAt, clock.value);
    expect(completed.leaseToken, isNull);
    expect(completed.leaseExpiresAt, isNull);
  });

  test('wipeAll removes queued jobs and owned audio', () async {
    final ledger = await openLedger();
    final first = await ledger.enqueue(await audio('wipe-first.m4a'));
    final second = await ledger.enqueue(await audio('wipe-second.m4a'));

    await ledger.wipeAll();

    expect(ledger.jobs, isEmpty);
    expect(await File(first.audioPath).exists(), isFalse);
    expect(await File(second.audioPath).exists(), isFalse);
    expect(ledger.audioDirectory.listSync(), isEmpty);
  });

  test('integrity check and consistent snapshot support backup', () async {
    final ledger = await openLedger();
    await ledger.enqueue(await audio('backup.m4a'));

    expect(ledger.checkIntegrity().isHealthy, isTrue);
    final snapshot = ledger.createDatabaseSnapshot(
      '${temporaryDirectory.path}/backup/transcription.sqlite3',
    );
    expect(snapshot.existsSync(), isTrue);

    final backup = TranscriptionJobDatabase.open(
      databasePath: snapshot.path,
      clock: clock.call,
      tokenFactory: () => 'unused',
    );
    addTearDown(backup.close);
    expect(backup.listJobs().single.id, 'job-1');
    expect(backup.checkIntegrity().isHealthy, isTrue);
  });
}

class _FakeClock {
  _FakeClock(this.value);

  DateTime value;

  DateTime call() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}
