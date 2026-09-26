import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/sync/e2ee_journal_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JournalEntry entry({
    required String id,
    required DateTime updatedAt,
    required String transcript,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 3, 8),
      transcript: transcript,
      durationSeconds: 4,
      reflection: const Reflection(
        mood: 'quiet',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      updatedAt: updatedAt,
    );
  }

  test('last write wins keeps the newer updated_at', () {
    final older = entry(
      id: 'river',
      updatedAt: DateTime.utc(2026, 3, 8, 12),
      transcript: 'the river was high',
    );
    final newer = entry(
      id: 'river',
      updatedAt: DateTime.utc(2026, 3, 9, 12),
      transcript: 'the river fell overnight',
    );

    expect(E2eeJournalSync.lastWriteWins(older, newer).transcript, newer.transcript);
    expect(E2eeJournalSync.lastWriteWins(newer, older).transcript, newer.transcript);

    final merged = E2eeJournalSync.mergeByUpdatedAt(
      local: [older],
      remote: [
        newer,
        entry(
          id: 'market',
          updatedAt: DateTime.utc(2026, 3, 8, 18),
          transcript: 'the market was loud',
        ),
      ],
    );
    expect(merged.map((row) => row.id), containsAll(['river', 'market']));
    expect(merged.firstWhere((row) => row.id == 'river').transcript, newer.transcript);
  });
}
