import 'package:archiveme_mobile/features/settings/views/sync_status_view.dart';
import 'package:archiveme_mobile/features/sync/services/entry_conflict_resolver.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required DateTime updatedAt,
  required String transcript,
  required String mood,
  required String title,
  required String tag,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 3, 8);
  final entry = JournalEntry(
    id: 'river',
    createdAt: created,
    transcript: transcript,
    durationSeconds: 4,
    captureContextTag: tag,
    reflection: Reflection(
      mood: mood,
      emotionalIntensity: 1,
      recurringThemes: [tag],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    updatedAt: updatedAt,
  );
  return entry.copyWith(
    display: entry.display.copyWith(title: title, captureContextTag: tag),
  );
}

void main() {
  tearDown(() => TranscriptConflictStore.clear('river'));

  test('newer metadata wins and both transcripts stay', () {
    final local = _entry(
      updatedAt: DateTime.utc(2026, 3, 8, 12),
      transcript: 'the river was high',
      mood: 'quiet',
      title: 'Morning',
      tag: 'home',
    );
    final remote = _entry(
      updatedAt: DateTime.utc(2026, 3, 9, 12),
      createdAt: DateTime.utc(2026, 3, 9),
      transcript: 'the river fell overnight',
      mood: 'calm',
      title: 'Next day',
      tag: 'walk',
    );

    final merged = EntryConflictResolver.merge(local: local, remote: remote);

    expect(merged.entry.display.title, 'Next day');
    expect(merged.entry.reflection.mood, 'calm');
    expect(merged.entry.captureContextTag, 'walk');
    expect(merged.entry.createdAt, DateTime.utc(2026, 3, 9));
    expect(merged.entry.transcript, 'the river was high');
    expect(merged.transcripts?.remoteText, 'the river fell overnight');
    expect(
      TranscriptConflictStore.read('river')?.localText,
      'the river was high',
    );
  });

  test('the same transcript is not treated as a conflict', () {
    final local = _entry(
      updatedAt: DateTime.utc(2026, 3, 8, 12),
      transcript: 'the river was high',
      mood: 'quiet',
      title: 'Morning',
      tag: 'home',
    );
    final remote = _entry(
      updatedAt: DateTime.utc(2026, 3, 8, 13),
      transcript: 'the river was high',
      mood: 'calm',
      title: 'Later',
      tag: 'home',
    );

    final merged = EntryConflictResolver.merge(local: local, remote: remote);

    expect(merged.transcriptDiverged, isFalse);
    expect(merged.entry.reflection.mood, 'calm');
    expect(merged.entry.transcript, 'the river was high');
  });

  testWidgets('status line counts active devices and revoke drops the token', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 26, 8);
    await tester.pumpWidget(
      MaterialApp(
        home: SyncStatusView(
          now: now,
          syncedAt: now.subtract(const Duration(minutes: 2)),
          devices: [
            ConnectedDevice(
              id: 'phone',
              name: 'This iPhone',
              lastActive: now.subtract(const Duration(minutes: 2)),
              syncToken: 'token-phone',
            ),
            ConnectedDevice(
              id: 'ipad',
              name: 'iPad',
              lastActive: now.subtract(const Duration(hours: 3)),
              syncToken: 'token-ipad',
            ),
            ConnectedDevice(
              id: 'mac',
              name: 'Mac',
              lastActive: now.subtract(const Duration(days: 1)),
              syncToken: 'token-mac',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Synced 2 min ago · 3 devices'), findsOneWidget);
    await tester.tap(find.byKey(const Key('revoke_device_ipad')));
    await tester.pump();
    expect(find.text('Synced 2 min ago · 2 devices'), findsOneWidget);
    expect(find.text('Removed'), findsOneWidget);
    expect(find.byKey(const Key('revoke_device_ipad')), findsNothing);
  });

  testWidgets('the prompt asks which transcript to keep', (tester) async {
    String? kept;
    final split = TranscriptSplit(
      localText: 'the river was high',
      remoteText: 'the river fell overnight',
      localUpdatedAt: DateTime.utc(2026, 3, 8),
      remoteUpdatedAt: DateTime.utc(2026, 3, 9),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TranscriptConflictPrompt(
            split: split,
            onKeep: (text) => kept = text,
          ),
        ),
      ),
    );

    expect(
      find.text('Conflicting edits detected. Choose version to keep.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('transcript_keep_remote')));
    expect(kept, 'the river fell overnight');
  });
}
