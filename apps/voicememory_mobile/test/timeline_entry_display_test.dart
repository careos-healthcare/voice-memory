import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/timeline/timeline_entry_display.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

Reflection _reflection({String observation = 'You keep returning to career change.'}) {
  return Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: observation,
    repeatedSignal: '',
  );
}

JournalEntry _entry({
  String transcript = 'Thinking about career changes',
  String observation = 'You keep returning to career change.',
  SyncStatus sync = SyncStatus.pendingUpload,
}) {
  return JournalEntry(
    id: '1',
    createdAt: DateTime.utc(2026, 5, 25, 14, 30),
    transcript: transcript,
    durationSeconds: 42,
    reflection: _reflection(observation: observation),
    syncStatus: sync,
  );
}

void main() {
  test('prefers transcript snippet', () {
    expect(
      timelineEntryTitle(_entry()),
      'Thinking about career changes',
    );
  });

  test('skips transport errors and uses reflection', () {
    expect(
      timelineEntryTitle(
        _entry(
          transcript: 'Connection refused',
          observation: 'You sound uncertain about the move.',
        ),
      ),
      'You sound uncertain about the move.',
    );
  });

  test('skips cloud-processing placeholder transcript and uses real observation',
      () {
    const observation = 'You mentioned pressure before saying yes.';
    final title = timelineEntryTitle(
      _entry(
        transcript: 'Saved on this device. Cloud processing pending.',
        observation: observation,
      ),
    );
    expect(title, observation);
    expect(title, isNot(contains('Cloud processing')));
  });

  test('allows saved privately on device as reflection title', () {
    final title = timelineEntryTitle(
      _entry(
        transcript: 'Saved on this device. Cloud processing pending.',
        observation: ConsumerUiCopy.savedPrivatelyOnDevice,
      ),
    );
    expect(title, ConsumerUiCopy.savedPrivatelyOnDevice);
  });

  test('skips draft placeholder transcript and uses real observation', () {
    const observation = 'You sounded tired when talking about work.';
    final title = timelineEntryTitle(
      _entry(
        transcript: '[draft] Recording saved locally — transcribe when connected',
        observation: observation,
      ),
    );
    expect(title, observation);
  });

  test('skips draft placeholder reflection', () {
    final title = timelineEntryTitle(
      _entry(
        transcript: '[draft] Recording saved locally — transcribe when connected',
        observation: '[draft] Recording saved locally — transcribe when connected',
      ),
    );
    expect(title, startsWith('Recording ·'));
  });

  test('sync badge offline for pending upload', () {
    expect(
      timelineSyncBadgeLabel(SyncStatus.pendingUpload),
      'Offline',
    );
    expect(timelineSyncBadgeLabel(SyncStatus.synced), isNull);
  });
}
