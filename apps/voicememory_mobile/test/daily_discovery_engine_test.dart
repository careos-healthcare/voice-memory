import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_explanations/explanation_models.dart';
import 'package:voicememory_mobile/features/daily_discoveries/daily_discovery_engine.dart';
import 'package:voicememory_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:voicememory_mobile/features/daily_discoveries/daily_discovery_store.dart';
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
      journalPath: '/tmp/vm_daily_disc_$stamp.json',
      prefsPath: '/tmp/vm_daily_disc_prefs_$stamp.json',
    );
  });

  test('theme decline discovery requires evidence and baseline', () {
    final priorMonth = List.generate(
      6,
      (i) => _entry(
        id: 'old$i',
        at: DateTime.now().subtract(Duration(days: 45 + i)),
        line: 'I need approval and validation from everyone around me',
        themes: const ['relationship'],
      ),
    );
    final thisMonth = List.generate(
      6,
      (i) => _entry(
        id: 'new$i',
        at: DateTime.now().subtract(Duration(days: i + 1)),
        line: 'Quiet evening walk and journaling about the day',
        themes: const ['health'],
      ),
    );
    final entries = [...priorMonth, ...thisMonth];

    const engine = DailyDiscoveryEngine();
    final baseline = engine.detectDiscovery(
      entries: priorMonth,
      baseline: null,
      viewedIds: {},
    );

    final workingBelief = 'Quiet evening walk and journaling about the day';

    final discovery = engine.detectDiscovery(
      entries: entries,
      baseline: DailyDiscoveryBaseline(
        lastEntryId: priorMonth.last.id,
        entryCount: priorMonth.length,
        belief: workingBelief,
        themeCounts: {'approval': 6},
        contradictionIds: const [],
        latestChapterId: null,
        avgEmotionalIntensity: 4,
        beliefStrengthPercent: 100,
      ),
      viewedIds: {},
    );

    expect(discovery, isNotNull);
    expect(discovery!.type, DailyDiscoveryType.themeDecline);
    expect(discovery.evidenceIds, isNotEmpty);
    expect(discovery.summary.toLowerCase(), isNot(contains('something new')));
    expect(
      discovery.summary.toLowerCase(),
      contains('last 3 recordings'),
    );
  });

  test('new entry replaces stale pending discovery', () async {
    final store = DailyDiscoveryStore(AppServices.instance.prefs);
    final priorMonth = List.generate(
      6,
      (i) => _entry(
        id: 'old$i',
        at: DateTime.now().subtract(Duration(days: 45 + i)),
        line: 'I need approval and validation from everyone at work',
      ),
    );
    final thisMonth = List.generate(
      5,
      (i) => _entry(
        id: 'new$i',
        at: DateTime.now().subtract(Duration(days: i + 2)),
        line: 'Quiet reflection about confidence without approval words',
      ),
    );
    final baseEntries = [...priorMonth, ...thisMonth];

    await store.writeBaseline(
      DailyDiscoveryBaseline(
        lastEntryId: thisMonth.last.id,
        entryCount: baseEntries.length,
        belief: null,
        themeCounts: const {'approval': 6},
        contradictionIds: const [],
        latestChapterId: null,
        avgEmotionalIntensity: 4,
        beliefStrengthPercent: 40,
      ),
    );
    await store.writePending(
      DailyDiscovery(
        id: 'daily:stale-pending',
        type: DailyDiscoveryType.emotionalShift,
        title: 'Stale',
        summary: 'Old pending card before a new recording.',
        whyItMatters: 'Should refresh when journal grows.',
        evidenceIds: const ['old0', 'old1'],
        confidence: 70,
        createdAt: DateTime(2026, 3, 8),
        insightRef: ArchiveInsightRef.belief(),
      ),
    );

    final grown = [
      ...baseEntries,
      _entry(
        id: 'brand-new',
        at: DateTime.now(),
        line: 'Another quiet reflection without approval or validation',
      ),
    ];

    const engine = DailyDiscoveryEngine();
    final loaded = await engine.loadTodayDiscovery(
      store: store,
      entries: grown,
    );

    expect(loaded, isNotNull);
    expect(loaded!.id, isNot('daily:stale-pending'));
    expect(loaded.summary.toLowerCase(), contains('approval'));
  });

  test('viewed discovery ids are not repeated', () async {
    final store = DailyDiscoveryStore(AppServices.instance.prefs);
    await store.markViewed('daily:theme-decline:approval:1');

    final entries = List.generate(
      12,
      (i) => _entry(
        id: 'e$i',
        at: DateTime.now().subtract(Duration(days: 40 - i)),
        line: i < 6
            ? 'I need approval validation approval again'
            : 'Confidence reflection without approval',
      ),
    );

    const engine = DailyDiscoveryEngine();
    final d = engine.detectDiscovery(
      entries: entries,
      baseline: DailyDiscoveryBaseline(
        lastEntryId: 'e0',
        entryCount: 1,
        belief: null,
        themeCounts: {'approval': 6},
        contradictionIds: const [],
        latestChapterId: null,
        avgEmotionalIntensity: 4,
        beliefStrengthPercent: 40,
      ),
      viewedIds: await store.readViewedIds(),
    );

    if (d != null) {
      expect(d.id, isNot('daily:theme-decline:approval:1'));
    }
  });

  test('no discovery without new entries since baseline', () async {
    final store = DailyDiscoveryStore(AppServices.instance.prefs);
    final entries = List.generate(
      8,
      (i) => _entry(
        id: 's$i',
        at: DateTime(2026, 3, i + 1),
        line: 'Steady reflection line $i with enough transcript',
      ),
    );

    const engine = DailyDiscoveryEngine();
    final snap = DailyDiscovery(
      id: 'daily:test-pending',
      type: DailyDiscoveryType.emotionalShift,
      title: 'Test',
      summary: 'Test summary with specific evidence-backed wording.',
      whyItMatters: 'Test matters.',
      evidenceIds: ['s0', 's1'],
      confidence: 70,
      createdAt: DateTime(2026, 3, 8),
      insightRef: ArchiveInsightRef.belief(),
    );

    await store.writeBaseline(
      DailyDiscoveryBaseline(
        lastEntryId: entries.last.id,
        entryCount: entries.length,
        belief: null,
        themeCounts: const {},
        contradictionIds: const [],
        latestChapterId: null,
        avgEmotionalIntensity: 3,
        beliefStrengthPercent: 0,
      ),
    );
    await store.writePending(snap);

    final again = await engine.loadTodayDiscovery(
      store: store,
      entries: entries,
    );
    expect(again?.id, snap.id);

    await engine.acknowledgeDiscovery(
      store: store,
      discovery: snap,
      entries: entries,
    );
    final afterAck = await engine.loadTodayDiscovery(
      store: store,
      entries: entries,
    );
    expect(afterAck, isNull);
  });

  test('detectImmediateDiscovery uses pre-save baseline', () async {
    final priorMonth = List.generate(
      6,
      (i) => _entry(
        id: 'old$i',
        at: DateTime.now().subtract(Duration(days: 45 + i)),
        line: 'I need approval and validation from everyone around me',
      ),
    );
    final thisMonth = List.generate(
      5,
      (i) => _entry(
        id: 'new$i',
        at: DateTime.now().subtract(Duration(days: i + 2)),
        line: 'Quiet evening walk and journaling about the day',
        themes: const ['health'],
      ),
    );
    final entries = [
      ...priorMonth,
      ...thisMonth,
      _entry(
        id: 'just-saved',
        at: DateTime.now(),
        line: 'Another quiet evening without approval language',
      ),
    ];

    const engine = DailyDiscoveryEngine();
    final discovery = await engine.detectImmediateDiscovery(
      store: DailyDiscoveryStore(AppServices.instance.prefs),
      entries: entries,
    );

    expect(discovery, isNotNull);
    expect(discovery!.evidenceIds.length, greaterThanOrEqualTo(2));
    expect(discovery.summary.toLowerCase(), contains('approval'));
  });

  test('DailyDiscovery round-trips JSON', () {
    final d = DailyDiscovery(
      id: 'daily:test:1',
      type: DailyDiscoveryType.themeDecline,
      title: 'Less approval',
      summary: 'You talk about approval less than last month.',
      whyItMatters: 'Language shifts matter.',
      evidenceIds: const ['a', 'b'],
      confidence: 72,
      createdAt: DateTime(2026, 5, 1),
      insightRef: ArchiveInsightRef.theme('approval'),
    );
    final restored = DailyDiscovery.fromJson(d.toJson());
    expect(restored?.id, d.id);
    expect(restored?.evidenceIds, d.evidenceIds);
  });
}
