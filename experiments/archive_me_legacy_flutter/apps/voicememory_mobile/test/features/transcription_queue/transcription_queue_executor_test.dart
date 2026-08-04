import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_queue.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late TranscriptionLedger ledger;
  late JournalStore journal;
  var sequence = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('queue_executor_test_');
    ledger = await TranscriptionLedger.open(
      directory: Directory('${root.path}/queue'),
      idFactory: () => 'job-${sequence++}',
      leaseTokenFactory: () => 'lease-${sequence++}',
    );
    journal = await JournalStore.open(
      '${root.path}/journal.json',
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
  });

  tearDown(() async {
    await ledger.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> audio() async {
    final file = File('${root.path}/recording.wav');
    await file.writeAsBytes(List<int>.filled(256, 7), flush: true);
    return file;
  }

  JournalEntry entry(String id) => JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 7, 24),
    transcript: 'A durable transcript',
    durationSeconds: 42,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );

  test('completes atomically before deleting durable audio', () async {
    final job = await ledger.enqueue(
      await audio(),
      durationSeconds: 42,
      entryId: 'entry-1',
    );
    final executor = TranscriptionQueueExecutor(
      ledger: ledger,
      journal: journal,
      runPipeline: (job) async {
        final saved = entry(job.entryId);
        await journal.save(saved);
        return CapturePipelineResult(
          entry: saved,
          localSaved: true,
          syncSucceeded: true,
          analysisSucceeded: true,
        );
      },
    );

    expect(await executor.drain(), 1);

    expect(ledger.getJob(job.id)?.status, TranscriptionJobStatus.completed);
    expect(await File(job.audioPath).exists(), isFalse);
    expect((await journal.loadAll()).single.id, 'entry-1');
  });

  test(
    'emits the durable pipeline result after foreground completion',
    () async {
      final job = await ledger.enqueue(
        await audio(),
        durationSeconds: 42,
        entryId: 'entry-visible-after-save',
      );
      final saved = entry(job.entryId);
      final executor = TranscriptionQueueExecutor(
        ledger: ledger,
        journal: journal,
        runPipeline: (_) async {
          await journal.save(saved);
          return CapturePipelineResult(
            entry: saved,
            localSaved: true,
            syncSucceeded: true,
            analysisSucceeded: true,
          );
        },
      );
      addTearDown(executor.dispose);
      final completion = executor.completions.first;

      expect(await executor.drain(), 1);
      final event = await completion;

      expect(event.job.entryId, job.entryId);
      expect(event.result.entry.id, saved.id);
      expect(ledger.getJob(job.id)?.status, TranscriptionJobStatus.completed);
      expect(await File(job.audioPath).exists(), isFalse);
    },
  );

  test('retries sanitized failures and retains audio', () async {
    var schedules = 0;
    final job = await ledger.enqueue(await audio(), durationSeconds: 9);
    final executor = TranscriptionQueueExecutor(
      ledger: ledger,
      journal: journal,
      runPipeline: (_) async => throw Exception('private server detail'),
      onRetryScheduled: () async => schedules++,
    );

    await executor.drain();

    final retried = ledger.getJob(job.id)!;
    expect(retried.status, TranscriptionJobStatus.retryWaiting);
    expect(retried.lastError, 'transcription_unavailable');
    expect(retried.lastError, isNot(contains('private')));
    expect(await File(job.audioPath).exists(), isTrue);
    expect(schedules, 1);
  });

  test('does not emit a completion when processing is retried', () async {
    final job = await ledger.enqueue(await audio(), durationSeconds: 9);
    final executor = TranscriptionQueueExecutor(
      ledger: ledger,
      journal: journal,
      runPipeline: (_) async => throw Exception('temporary failure'),
    );
    addTearDown(executor.dispose);
    var completions = 0;
    final subscription = executor.completions.listen((_) => completions++);
    addTearDown(subscription.cancel);

    await executor.drain();

    expect(ledger.getJob(job.id)?.status, TranscriptionJobStatus.retryWaiting);
    expect(completions, 0);
  });

  test('existing stable entry makes completion idempotent', () async {
    final job = await ledger.enqueue(await audio(), entryId: 'already-saved');
    await journal.save(entry('already-saved'));
    var pipelineCalls = 0;
    final executor = TranscriptionQueueExecutor(
      ledger: ledger,
      journal: journal,
      runPipeline: (_) async {
        pipelineCalls++;
        throw StateError('must not run');
      },
    );

    await executor.drain();

    expect(pipelineCalls, 0);
    expect(ledger.getJob(job.id)?.status, TranscriptionJobStatus.completed);
  });

  test(
    'typed recovery cancellation preserves the typed entry and removes audio',
    () async {
      final job = await ledger.enqueue(await audio(), entryId: 'typed-entry');
      await journal.save(entry('typed-entry'));

      await ledger.cancelAndDeleteAudio(job.id);

      expect(ledger.getJob(job.id)?.status, TranscriptionJobStatus.cancelled);
      expect(await File(job.audioPath).exists(), isFalse);
      expect(await journal.getById('typed-entry'), isNotNull);
    },
  );
}
