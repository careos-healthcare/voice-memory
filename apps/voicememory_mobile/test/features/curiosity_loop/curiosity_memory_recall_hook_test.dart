import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/interceptors/curiosity_loop_trigger_interceptor.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_loop_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/application/curiosity_hook_coordinator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/application/curiosity_hook_journal_store.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/curiosity_prompt_generator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_memory_recall_hook_enricher.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_notification_scheduler.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import '../../support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  CognitiveBiomarkers? biomarkers,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 12, 12),
    transcript: transcript,
    durationSeconds: 30,
    localAudioPath: '/tmp/$id.m4a',
    biomarkers: biomarkers,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> _confirmedRepeatEntries(int count) {
  const transcripts = [
    'I had no capacity but I said yes again to the extra meeting today.',
    'Same thing — said yes when I had no capacity for one more thing.',
    'I said yes again even though I had no capacity for one more ask.',
  ];
  return List.generate(
    count,
    (i) => _entry(
      id: 'repeat_$i',
      transcript: transcripts[i % transcripts.length],
      createdAt: DateTime.utc(2026, 6, 10 + i, 12),
      biomarkers: const CognitiveBiomarkers(
        lexicalDiversity: 0.72,
        cohesionDrift: 0.18,
        emotionalVolatility: 0.41,
      ),
    ),
  );
}

class _FakeCuriosityNotificationScheduler
    extends CuriosityNotificationScheduler {
  _FakeCuriosityNotificationScheduler();

  int initializeCalls = 0;
  int scheduleCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> scheduleCuriosityNotification(
    CuriosityHook hook, {
    Duration scheduleAfter =
        CuriosityNotificationScheduler.defaultScheduleAfter,
    String? promptBody,
  }) async {
    scheduleCalls++;
    return true;
  }
}

class _FakeJournalStore implements CuriosityHookJournalStore {
  _FakeJournalStore(this.entries);

  final Map<String, JournalEntry> entries;
  final requestedEntryIds = <String>[];

  @override
  Future<JournalEntry?> getEntryById(String entryId) async {
    requestedEntryIds.add(entryId);
    return entries[entryId];
  }
}

class _FakePromptGenerator implements CuriosityPromptGenerator {
  _FakePromptGenerator(this.prompt);

  final String prompt;
  final requestedHooks = <CuriosityHook>[];
  final requestedSourceEntries = <JournalEntry?>[];

  @override
  Future<String> generatePrompt({
    required CuriosityHook hook,
    JournalEntry? sourceEntry,
  }) async {
    requestedHooks.add(hook);
    requestedSourceEntries.add(sourceEntry);
    return prompt;
  }
}

void main() {
  late TestStorageSandbox sandbox;
  late MobilePrefsStore prefs;
  late LocalCuriosityLoopRepository curiosityLoopRepository;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    prefs = AppServices.instance.prefs;
    await LocalCuriosityHookRepository.resetForTest(prefs);
    await LocalCuriosityLoopRepository.resetForTest(prefs);
    curiosityLoopRepository = LocalCuriosityLoopRepository.forPrefs(prefs);
    CuriosityHookCoordinator.resetForTest();
    CuriosityNotificationScheduler.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  group('CuriosityMemoryRecallHookEnricher', () {
    test('applies pending seed to a later hook and clears it', () async {
      final enricher = CuriosityMemoryRecallHookEnricher(
        repository: curiosityLoopRepository,
      );
      final seededAt = DateTime.utc(2026, 6, 12, 10);
      await curiosityLoopRepository.seedMemoryRecallCheck(
        sourceEntryId: 'repeat_0',
        seededAt: seededAt,
      );

      final hook = CuriosityHook(
        id: 'hook_1',
        entryId: 'repeat_1',
        createdAt: DateTime.utc(2026, 6, 12, 12),
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.blocker,
        dynamicPrompt:
            'Before "said yes again" showed up again, what got in the way?',
      );

      final enriched = await enricher.applyPendingSeed(hook);

      expect(enriched.sourceEntryId, 'repeat_0');
      expect(enriched.isMemoryRecallCheck, isTrue);
      expect(
        await curiosityLoopRepository.fetchPendingMemoryRecallSeed(),
        isNull,
      );
    });

    test('keeps pending seed when hook targets the same entry', () async {
      final enricher = CuriosityMemoryRecallHookEnricher(
        repository: curiosityLoopRepository,
      );
      await curiosityLoopRepository.seedMemoryRecallCheck(
        sourceEntryId: 'repeat_0',
        seededAt: DateTime.utc(2026, 6, 12, 10),
      );

      final hook = CuriosityHook(
        id: 'hook_1',
        entryId: 'repeat_0',
        createdAt: DateTime.utc(2026, 6, 12, 12),
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.blocker,
        dynamicPrompt:
            'Before "said yes again" showed up again, what got in the way?',
      );

      final enriched = await enricher.applyPendingSeed(hook);

      expect(enriched.isMemoryRecallCheck, isFalse);
      expect(enriched.sourceEntryId, isNull);
      expect(
        await curiosityLoopRepository.fetchPendingMemoryRecallSeed(),
        isNotNull,
      );
    });
  });

  group('CuriosityLoopTriggerInterceptor', () {
    test('does not overwrite an existing pending seed', () async {
      final seededAt = DateTime.utc(2026, 6, 12, 10);
      await curiosityLoopRepository.seedMemoryRecallCheck(
        sourceEntryId: 'repeat_0',
        seededAt: seededAt,
      );
      final interceptor = CuriosityLoopTriggerInterceptor(
        repository: curiosityLoopRepository,
      );

      await interceptor.onEntrySaved(
        _entry(
          id: 'repeat_1',
          transcript: 'One two three four five six seven eight.',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.72,
            cohesionDrift: 0.18,
            emotionalVolatility: 0.41,
          ),
        ),
      );

      expect(
        await curiosityLoopRepository.fetchPendingMemoryRecallSeed(),
        CuriosityMemoryRecallSeed(
          sourceEntryId: 'repeat_0',
          seededAt: seededAt,
        ),
      );
    });
  });

  group('CuriosityHookCoordinator', () {
    test(
      'applies pending memory recall seed to the next generated hook',
      () async {
        final entries = _confirmedRepeatEntries(3);
        await curiosityLoopRepository.seedMemoryRecallCheck(
          sourceEntryId: entries.first.id,
          seededAt: DateTime.utc(2026, 6, 12, 10),
        );

        final scheduler = _FakeCuriosityNotificationScheduler();
        final coordinator = CuriosityHookCoordinator(
          scheduler: scheduler,
          memoryRecallEnricher: CuriosityMemoryRecallHookEnricher(
            repository: curiosityLoopRepository,
          ),
          journalStore: _FakeJournalStore({
            for (final entry in entries) entry.id: entry,
          }),
          promptGenerator: const DefaultCuriosityPromptGenerator(),
        );

        final hook = await coordinator.persistAfterVoiceSave(
          savedEntry: entries.last,
          allEntries: entries,
        );

        expect(hook, isNotNull);
        expect(hook!.entryId, entries.last.id);
        expect(hook.sourceEntryId, entries.first.id);
        expect(hook.isMemoryRecallCheck, isTrue);

        final stored = await LocalCuriosityHookRepository.instance()
            .fetchLatestUnconsumed();
        expect(stored?.sourceEntryId, entries.first.id);
        expect(stored?.isMemoryRecallCheck, isTrue);
        expect(
          await curiosityLoopRepository.fetchPendingMemoryRecallSeed(),
          isNull,
        );
      },
    );

    test('looks up source entry and persists synthesized prompt', () async {
      final entries = _confirmedRepeatEntries(3);
      const synthesizedPrompt =
          'You touched on said yes again recently. How does it look right now? Short thoughts are perfect.';
      await curiosityLoopRepository.seedMemoryRecallCheck(
        sourceEntryId: entries.first.id,
        seededAt: DateTime.utc(2026, 6, 12, 10),
      );

      final journalStore = _FakeJournalStore({
        entries.first.id: entries.first.copyWith(
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.42,
            cohesionDrift: 0.2,
            emotionalVolatility: 0.3,
          ),
        ),
        entries.last.id: entries.last,
      });
      final promptGenerator = _FakePromptGenerator(synthesizedPrompt);
      final coordinator = CuriosityHookCoordinator(
        scheduler: _FakeCuriosityNotificationScheduler(),
        memoryRecallEnricher: CuriosityMemoryRecallHookEnricher(
          repository: curiosityLoopRepository,
        ),
        journalStore: journalStore,
        promptGenerator: promptGenerator,
      );

      final hook = await coordinator.persistAfterVoiceSave(
        savedEntry: entries.last,
        allEntries: entries,
      );

      expect(hook?.dynamicPrompt, synthesizedPrompt);
      expect(journalStore.requestedEntryIds, contains(entries.first.id));
      expect(promptGenerator.requestedHooks, hasLength(1));
      expect(
        promptGenerator.requestedHooks.single.sourceEntryId,
        entries.first.id,
      );
      expect(
        promptGenerator.requestedSourceEntries.single?.id,
        entries.first.id,
      );

      final stored = await LocalCuriosityHookRepository.instance()
          .fetchLatestUnconsumed();
      expect(stored?.dynamicPrompt, synthesizedPrompt);
    });
  });
}
