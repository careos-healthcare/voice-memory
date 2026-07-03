import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/belief_update_payoff.dart';
import 'package:voicememory_mobile/features/post_save/post_save_archive_hierarchy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRepeatCapacityEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _fourRepeatCapacityEntries() => [
      ..._threeRepeatCapacityEntries(),
      _entry(
        id: 'e4',
        transcript:
            'The same yes-with-no-capacity pattern showed up again at work today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

void main() {
  group('PostSaveArchiveHierarchy', () {
    test('low-signal newest entry wins over belief update', () {
      final entries = [
        ..._fourRepeatCapacityEntries(),
        _entry(id: 'e5', transcript: 'Test'),
      ];

      final belief = BeliefUpdatePayoffEngine.build(entries: entries);
      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: true,
        beliefUpdatePayoff: belief,
      );

      expect(hierarchy.kind, PostSavePrimaryArchiveKind.lowSignal);
      expect(hierarchy.showBeliefUpdateCard, isFalse);
    });

    test('discovery wins over belief update when both are available', () {
      final entries = _fourRepeatCapacityEntries();
      final belief = BeliefUpdatePayoffEngine.build(entries: entries);

      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: false,
        beliefUpdatePayoff: belief,
      );

      expect(belief, isNotNull);
      expect(hierarchy.kind, PostSavePrimaryArchiveKind.discovery);
      expect(hierarchy.showBeliefUpdateCard, isFalse);
    });

    test('belief update is primary when discovery is absent', () {
      final entries = _fourRepeatCapacityEntries();
      final belief = BeliefUpdatePayoffEngine.build(entries: entries);

      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: false,
        beliefUpdatePayoff: belief,
        mirror: null,
      );

      expect(belief, isNotNull);
      expect(
        hierarchy.kind,
        anyOf(
          PostSavePrimaryArchiveKind.discovery,
          PostSavePrimaryArchiveKind.beliefUpdate,
        ),
      );
    });

    test('first entry resolves to first-entry footnote', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'A long enough transcript to count as a saved reflection.',
        ),
      ];

      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: false,
        beliefUpdatePayoff: null,
      );

      expect(hierarchy.kind, PostSavePrimaryArchiveKind.firstEntryFootnote);
      expect(hierarchy.showMomentQualityCoach, isTrue);
    });

    test('three repeat entries prefer discovery over belief update card', () {
      final entries = _threeRepeatCapacityEntries();
      final belief = BeliefUpdatePayoffEngine.build(entries: entries);

      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: false,
        beliefUpdatePayoff: belief,
      );

      expect(belief, isNull);
      expect(hierarchy.kind, PostSavePrimaryArchiveKind.discovery);
    });

    test('belief update engine and discovery can both build for repeat archives', () {
      final entries = _fourRepeatCapacityEntries();
      final belief = BeliefUpdatePayoffEngine.build(entries: entries);
      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: false,
        beliefUpdatePayoff: belief,
      );

      expect(belief, isNotNull);
      expect(hierarchy.kind, PostSavePrimaryArchiveKind.discovery);
      expect(hierarchy.showBeliefUpdateCard, isFalse);
    });

    test('moment quality hidden when discovery is primary', () {
      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: _threeRepeatCapacityEntries(),
        suppressLatestSaveArchiveInsight: false,
        beliefUpdatePayoff: null,
      );

      expect(hierarchy.kind, PostSavePrimaryArchiveKind.discovery);
      expect(hierarchy.showMomentQualityCoach, isFalse);
    });

    test('first proof unlocked suppresses discovery and focused actions', () {
      final entries = _threeRepeatCapacityEntries();

      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: false,
        beliefUpdatePayoff: null,
        firstProofUnlocked: true,
      );

      expect(hierarchy.kind, PostSavePrimaryArchiveKind.firstProofUnlocked);
      expect(hierarchy.showFocusedActionsBar, isFalse);
      expect(hierarchy.showMomentQualityCoach, isFalse);
      expect(hierarchy.showBeliefUpdateCard, isFalse);
    });
  });
}
