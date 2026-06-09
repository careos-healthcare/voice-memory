import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:voicememory_mobile/features/surprise_engine/surprise_copy.dart';
import 'package:voicememory_mobile/features/archive_explanations/explanation_models.dart';
import 'package:voicememory_mobile/features/surprise_engine/surprise_coordinator.dart';
import 'package:voicememory_mobile/features/surprise_engine/surprise_engine.dart';
import 'package:voicememory_mobile/features/surprise_engine/surprise_models.dart';
import 'package:voicememory_mobile/features/surprise_engine/surprise_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
  int intensity = 4,
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — padding for evidence threshold in transcript body.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: intensity,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  setUp(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_surprise_$stamp.json',
      prefsPath: '/tmp/vm_surprise_prefs_$stamp.json',
    );
  });

  test('priority picks archive changed mind over theme spike', () {
    final priorMonth = List.generate(
      6,
      (i) => _entry(
        id: 'w$i',
        at: DateTime(2026, 3, i + 1),
        line: 'Work stress at the job and career pressure every day',
        themes: const ['work'],
      ),
    );
    final recent = List.generate(
      5,
      (i) => _entry(
        id: 'r$i',
        at: DateTime(2026, 5, i + 1),
        line: 'Partner and family relationship conflict wore me out',
        themes: const ['relationship'],
      ),
    );
    final entries = [...priorMonth, ...recent];

    final surprise = const SurpriseEngine().detect(
      entries: entries,
      discoveryBaseline: DailyDiscoveryBaseline(
        lastEntryId: 'w5',
        entryCount: 6,
        belief: 'Work defines my stress',
        themeCounts: const {'work': 6, 'career': 2},
        contradictionIds: const [],
        latestChapterId: null,
        avgEmotionalIntensity: 4,
        beliefStrengthPercent: 70,
      ),
    );

    expect(surprise, isNotNull);
    expect(surprise!.type, SurpriseType.archiveChangedMind);
  });

  test('theme disappearance maps to warm headline', () {
    final headline = SurpriseCopy.headlineFor(
      type: SurpriseType.themeDisappearance,
      themeLabel: 'approval',
    );
    expect(headline, contains('approval'));
    expect(headline, contains('less'));
  });

  test('store persists lastSurpriseSeenAt type and evidence', () async {
    final store = SurpriseStore(AppServices.instance.prefs);
    final surprise = ArchiveSurprise(
      id: 'surprise:test',
      type: SurpriseType.emotionalShift,
      headline: 'The emotional weight shifted.',
      why: 'Measured from your words.',
      evidenceIds: const ['a', 'b'],
      insightRef: ArchiveInsightRef.belief(),
      createdAt: DateTime(2026, 5, 1),
    );

    await store.markSeen(surprise);
    final state = await store.read();

    expect(state.lastSurpriseType, SurpriseType.emotionalShift);
    expect(state.lastSurpriseEvidence, ['a', 'b']);
    expect(state.lastSurpriseSeenAt, isNotNull);
  });

  test('dismissed surprise is not resurfaced for same entry', () async {
    final store = SurpriseStore(AppServices.instance.prefs);
    final surprise = ArchiveSurprise(
      id: 'surprise:dismiss:test',
      type: SurpriseType.newContradiction,
      headline: 'Tension appeared.',
      why: 'Two entries pull apart.',
      evidenceIds: const ['a', 'b'],
      insightRef: ArchiveInsightRef.belief(),
      createdAt: DateTime(2026, 5, 1),
    );

    final entries = List.generate(
      6,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2026, 5, i + 1),
        line: 'Steady reflection about work and relationships $i',
      ),
    );

    await store.writeActiveSurprise(
      surprise: surprise,
      lastEntryId: entries.last.id,
    );
    await store.dismiss(surprise);

    final resolved = await const SurpriseCoordinator().resolveForArchive(
      entries: entries,
    );

    expect(resolved?.id, isNot('surprise:dismiss:test'));
  });
}
