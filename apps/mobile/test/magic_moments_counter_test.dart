import 'package:archiveme_mobile/billing/magic_moments_counter.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(
  String id, {
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 20,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again.',
        repeatedSignal: 'Same thread returning.',
      ),
    );

List<JournalEntry> _threeRelatedRepeatEntries() => [
  _entry(
    'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

final DateTime _pressureBase = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _pressureRecord({
  required String id,
  int daysAgo = 0,
  List<String> contextIds = const [],
}) =>
    PressureCheckInRecord(
      entryId: id,
      createdAt: _pressureBase.subtract(Duration(days: daysAgo)),
      optionId: 'could_not_stop',
      contextIds: contextIds,
      transcript: 'pressure moment',
    );

void main() {
  group('MagicMomentsCounter', () {
    test('paywall threshold is three distinct evidence milestones', () {
      expect(MagicMomentsCounter.paywallThreshold, 3);
      expect(MagicMomentsCounter.paywallEligible(2), isFalse);
      expect(MagicMomentsCounter.paywallEligible(3), isTrue);
    });

    test('empty journal yields zero evidence milestones', () {
      expect(MagicMomentsCounter.countFromJournalEntries(const []), 0);
    });

    test('confirmed repeat path counts distinct milestones without stacking', () {
      final entries = _threeRelatedRepeatEntries();
      expect(
        EarlyFirstSignalEngine.build(entries: entries)?.kind,
        EarlyFirstSignalKind.threeEntryConfirmedRepeat,
      );
      expect(MagicMomentsCounter.countFromJournalEntries(entries), 3);
    });

    test('pressure records do not double-count connected archive with thread', () {
      final records = [
        _pressureRecord(id: 'a', daysAgo: 5, contextIds: const ['work']),
        _pressureRecord(id: 'b', contextIds: const ['work']),
      ];
      expect(MagicMomentsCounter.countFromPressureRecords(records, now: _pressureBase), 2);
    });

    test('strong thread depth adds a second thread milestone at three appearances', () {
      final records = [
        _pressureRecord(id: 'a', daysAgo: 7, contextIds: const ['work']),
        _pressureRecord(id: 'b', daysAgo: 3, contextIds: const ['work']),
        _pressureRecord(id: 'c', contextIds: const ['work']),
      ];
      expect(MagicMomentsCounter.countFromPressureRecords(records, now: _pressureBase), 3);
    });
  });
}