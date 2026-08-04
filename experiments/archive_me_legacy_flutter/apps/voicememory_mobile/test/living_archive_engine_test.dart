import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:voicememory_mobile/features/living_archive/discovery_streak_engine.dart';
import 'package:voicememory_mobile/features/living_archive/discovery_streak_store.dart';
import 'package:voicememory_mobile/features/archive_explanations/explanation_models.dart';
import 'package:voicememory_mobile/features/living_archive/archive_was_wrong_engine.dart';
import 'package:voicememory_mobile/features/living_archive/living_archive_models.dart';
import 'package:voicememory_mobile/features/living_archive/most_important_insight_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — padding for evidence threshold in transcript body.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('archive was wrong detects theme dominance shift', () {
    final entries = <JournalEntry>[
      ...List.generate(
        6,
        (i) => _entry(
          id: 'w$i',
          at: DateTime(2026, 3, i + 1),
          line: 'Work stress at the job and career pressure every day',
          themes: const ['work'],
        ),
      ),
      ...List.generate(
        5,
        (i) => _entry(
          id: 'r$i',
          at: DateTime(2026, 5, i + 1),
          line: 'Partner and family relationship conflict wore me out',
          themes: const ['relationship'],
        ),
      ),
    ];

    final wrong = const ArchiveWasWrongEngine().detect(
      entries: entries,
      discoveryBaseline: DailyDiscoveryBaseline(
        lastEntryId: 'w5',
        entryCount: 6,
        belief: null,
        themeCounts: const {'work': 6, 'career': 2},
        contradictionIds: const [],
        latestChapterId: null,
        avgEmotionalIntensity: 4,
        beliefStrengthPercent: 70,
      ),
    );

    expect(wrong, isNotNull);
    expect(wrong!.evidenceIds.length, greaterThanOrEqualTo(2));
    expect(wrong.summary.toLowerCase(), contains('relationship'));
  });

  test('most important picks archive was wrong first', () {
    final wrong = ArchiveWasWrongInsight(
      id: 'wrong:test',
      headline: 'The archive changed its mind.',
      summary: 'Relationships now dominate.',
      evidenceIds: const ['a', 'b'],
      confidence: 80,
      insightRef: ArchiveInsightRef.belief(),
      shiftLabel: 'work → relationships',
    );

    final entries = List.generate(
      5,
      (i) => _entry(
        id: 'mi$i',
        at: DateTime(2026, 5, i + 1),
        line: 'Reflection about work and relationships $i',
      ),
    );

    final pick = const MostImportantInsightEngine().pick(
      entries: entries,
      wasWrong: wrong,
    );

    expect(pick?.priority, MostImportantInsightPriority.archiveWasWrong);
    expect(pick?.isArchiveWasWrong, isTrue);
  });

  test('discovery streak counts consecutive days', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_streak_$stamp.json',
      prefsPath: '/tmp/vm_streak_prefs_$stamp.json',
    );

    final store = DiscoveryStreakStore(AppServices.instance.prefs);
    final today = DateTime.now();
    await store.recordDiscoveryDay(today);
    await store.recordDiscoveryDay(today.subtract(const Duration(days: 1)));

    final days = await store.readDiscoveryDays();
    final streak = const DiscoveryStreakEngine().compute(days);
    expect(streak.consecutiveDays, greaterThanOrEqualTo(2));
  });
}
