import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_job.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services_providers.dart';

void main() {
  test('combined timeline keeps pending jobs newest first', () async {
    final now = DateTime.utc(2026, 7, 24, 12);
    final older = _job('older', now);
    final newer = _job('newer', now.add(const Duration(minutes: 1)));
    final container = ProviderContainer(
      overrides: [
        journalEntriesStreamProvider.overrideWith(
          (ref) => Stream.value([_entry()]),
        ),
        transcriptionJobsStreamProvider.overrideWith(
          (ref) => Stream.value([older, newer]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      transcriptionTimelineProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(journalEntriesStreamProvider.future);
    await container.read(transcriptionJobsStreamProvider.future);
    final timeline = container.read(transcriptionTimelineProvider).requireValue;

    expect(timeline.entries.single.id, 'entry');
    expect(timeline.pendingJobs.map((job) => job.id), ['newer', 'older']);
  });
}

TranscriptionJob _job(String id, DateTime createdAt) => TranscriptionJob(
  id: id,
  entryId: '$id-entry',
  audioPath: '/queue/$id.wav',
  sourceFileName: '$id.wav',
  durationSeconds: 20,
  status: TranscriptionJobStatus.queued,
  createdAt: createdAt,
  updatedAt: createdAt,
  attemptCount: 0,
);

JournalEntry _entry() => JournalEntry(
  id: 'entry',
  createdAt: DateTime.utc(2026, 7, 24),
  transcript: 'Past entry',
  durationSeconds: 12,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);
