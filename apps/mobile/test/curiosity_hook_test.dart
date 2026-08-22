import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_retention_policy.dart';
import 'package:archiveme_mobile/features/curiosity_loop/application/curiosity_hook_coordinator.dart';
import 'package:archiveme_mobile/features/curiosity_loop/application/curiosity_hook_journal_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/curiosity_hook_gates.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/curiosity_prompt_generator.dart';
import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_loop_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_hook_engine.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_hook_metadata_extractor.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_notification_scheduler.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  Reflection? reflection,
  String? localAudioPath,
  CognitiveBiomarkers? biomarkers,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
    transcript: transcript,
    durationSeconds: 30,
    localAudioPath: localAudioPath ?? '/tmp/$id.m4a',
    biomarkers: biomarkers,
    reflection:
        reflection ??
        const Reflection(
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
  final transcripts = [
    'I had no capacity but I said yes again to the extra meeting today.',
    'Same thing — said yes when I had no capacity for one more thing.',
    'I said yes again even though I had no capacity for one more ask.',
  ];
  return List.generate(
    count,
    (i) => _entry(
      id: 'repeat_$i',
      transcript: transcripts[i % transcripts.length],
      createdAt: DateTime(2026, 6, 10 + i, 12),
    ),
  );
}

Future<void> _resetStores(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_curiosity_journal_$stamp.json',
    prefsPath: '/tmp/vm_curiosity_prefs_$stamp.json',
  );
  await LocalCuriosityHookRepository.resetForTest(AppServices.instance.prefs);
  await LocalCuriosityLoopRepository.resetForTest(AppServices.instance.prefs);
}

void main() {
  group('CuriosityHook model', () {
    test('round trips through json', () {
      final hook = CuriosityHook(
        id: 'curiosity_e1_1',
        entryId: 'e1',
        createdAt: DateTime.utc(2026, 6, 12, 12),
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.blocker,
        dynamicPrompt:
            'Before "said yes again" showed up again, what got in the way?',
        sourceEntryId: 'e0',
        isMemoryRecallCheck: true,
      );

      final restored = CuriosityHook.fromJson(hook.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, hook.id);
      expect(restored.entryId, hook.entryId);
      expect(restored.primaryAnchor, hook.primaryAnchor);
      expect(restored.hookType, hook.hookType);
      expect(restored.dynamicPrompt, hook.dynamicPrompt);
      expect(restored.sourceEntryId, hook.sourceEntryId);
      expect(restored.isMemoryRecallCheck, hook.isMemoryRecallCheck);
      expect(restored.isConsumed, isFalse);
    });
  });

  group('CuriosityHookMetadataExtractor', () {
    test('detects blockers from capacity language', () {
      final entry = _entry(
        id: 'b1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
      );
      final metadata = CuriosityHookMetadataExtractor.fromEntry(
        entry: entry,
        allEntries: [entry],
      );

      expect(metadata.hasBlockers, isTrue);
      expect(metadata.extractedAnchors, isNotEmpty);
    });

    test(
      'uses grounded repeat phrases when archive has three related entries',
      () {
        final entries = _confirmedRepeatEntries(3);
        final metadata = CuriosityHookMetadataExtractor.fromEntry(
          entry: entries.last,
          allEntries: entries,
        );

        expect(metadata.entryCount, 3);
        expect(metadata.extractedAnchors.length, greaterThan(1));
      },
    );
  });

  group('CuriosityHookEngine', () {
    test('builds blocker hook from metadata', () {
      final hook = CuriosityHookEngine.build(
        metadata: CuriosityHookEntryMetadata(
          entryId: 'e1',
          createdAt: DateTime.utc(2026, 6, 12),
          extractedAnchors: const ['said yes again'],
          emotionalTone: 'thoughtful',
          hasBlockers: true,
          entryCount: 2,
        ),
      );

      expect(hook, isNotNull);
      expect(hook!.hookType, CuriosityHookType.blocker);
      expect(hook.dynamicPrompt, contains('what got in the way'));
    });

    test('avoids repeating the same hook type twice in a row', () {
      final first = CuriosityHookEngine.build(
        metadata: CuriosityHookEntryMetadata(
          entryId: 'e1',
          createdAt: DateTime.utc(2026, 6, 12),
          extractedAnchors: const ['said yes again'],
          hasBlockers: true,
          entryCount: 4,
        ),
      );
      final second = CuriosityHookEngine.build(
        metadata: CuriosityHookEntryMetadata(
          entryId: 'e2',
          createdAt: DateTime.utc(2026, 6, 13),
          extractedAnchors: const ['said yes again'],
          hasBlockers: true,
          entryCount: 4,
        ),
        recentHookTypes: [first!.hookType],
      );

      expect(second, isNotNull);
      expect(second!.hookType, isNot(CuriosityHookType.blocker));
    });
  });

  group('LocalCuriosityHookRepository', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_curiosity_repo_');
      await _resetStores(tempDir.path);
    });

    test('saves, fetches latest unconsumed, and marks consumed', () async {
      final repo = LocalCuriosityHookRepository.instance();
      final older = CuriosityHook(
        id: 'old',
        entryId: 'a',
        createdAt: DateTime.utc(2026, 6, 10),
        primaryAnchor: 'said yes',
        hookType: CuriosityHookType.anchorFollowUp,
        dynamicPrompt: 'Older prompt',
        isConsumed: true,
      );
      final latest = CuriosityHook(
        id: 'new',
        entryId: 'b',
        createdAt: DateTime.utc(2026, 6, 12),
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.momentum,
        dynamicPrompt: 'Latest prompt',
      );

      await repo.saveHook(older);
      await repo.saveHook(latest);

      expect(await repo.fetchLatestUnconsumed(), isNotNull);
      expect((await repo.fetchLatestUnconsumed())!.id, latest.id);
      await repo.markConsumed(latest.id);
      expect(await repo.fetchLatestUnconsumed(), isNull);
    });
  });

  group('CuriosityHookCoordinator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_curiosity_coord_');
      await _resetStores(tempDir.path);
      CuriosityHookCoordinator.resetForTest();
      CuriosityNotificationScheduler.resetForTest();
    });

    test('persists hook after a usable voice save', () async {
      final entries = _confirmedRepeatEntries(3);
      final scheduler = _FakeCuriosityNotificationScheduler();
      final coordinator = CuriosityHookCoordinator(scheduler: scheduler);
      final hook = await coordinator.persistAfterVoiceSave(
        savedEntry: entries.last,
        allEntries: entries,
      );

      expect(hook, isNotNull);
      expect(hook!.entryId, entries.last.id);
      final stored = await LocalCuriosityHookRepository.instance()
          .fetchLatestUnconsumed();
      expect(stored, isNotNull);
      expect(stored!.id, hook.id);
      await pumpEventQueue();
      expect(scheduler.initializeCalls, 1);
      expect(scheduler.scheduleCalls, 1);
      expect(scheduler.lastScheduledHook?.id, hook.id);
    });

    test('returns hook when notification scheduling fails', () async {
      final entries = _confirmedRepeatEntries(3);
      final scheduler = _FakeCuriosityNotificationScheduler(
        throwOnSchedule: true,
      );
      final coordinator = CuriosityHookCoordinator(scheduler: scheduler);
      final hook = await coordinator.persistAfterVoiceSave(
        savedEntry: entries.last,
        allEntries: entries,
      );

      expect(hook, isNotNull);
      await pumpEventQueue();
      expect(scheduler.scheduleCalls, 1);
    });

    test('returns hook when notification permission is denied', () async {
      final entries = _confirmedRepeatEntries(3);
      final scheduler = _FakeCuriosityNotificationScheduler(
        grantPermissions: false,
      );
      final coordinator = CuriosityHookCoordinator(scheduler: scheduler);
      final hook = await coordinator.persistAfterVoiceSave(
        savedEntry: entries.last,
        allEntries: entries,
      );

      expect(hook, isNotNull);
      await pumpEventQueue();
      expect(scheduler.requestPermissionCalls, 1);
      expect(scheduler.scheduleCalls, 0);
    });

    test('schedules synthesized notification prompt body', () async {
      final entries = _confirmedRepeatEntries(3);
      final savedEntry = entries.last.copyWith(
        biomarkers: const CognitiveBiomarkers(
          lexicalDiversity: 0.7,
          cohesionDrift: 0.81,
          emotionalVolatility: 0.3,
        ),
      );
      final allEntries = [
        ...entries.sublist(0, entries.length - 1),
        savedEntry,
      ];
      final scheduler = _FakeCuriosityNotificationScheduler();
      final coordinator = CuriosityHookCoordinator(
        scheduler: scheduler,
        journalStore: _FakeJournalStore({
          for (final entry in allEntries) entry.id: entry,
        }),
        promptGenerator: const DefaultCuriosityPromptGenerator(),
      );

      final hook = await coordinator.persistAfterVoiceSave(
        savedEntry: savedEntry,
        allEntries: allEntries,
      );
      await pumpEventQueue();

      expect(scheduler.scheduleCalls, 1);
      expect(hook?.dynamicPrompt, isNotNull);
      expect(
        hook!.dynamicPrompt,
        contains(DefaultCuriosityPromptGenerator.groundingLeadIn),
      );
      expect(scheduler.lastScheduledPromptBody, hook.dynamicPrompt);
    });

    test('skips degraded voice saves', () async {
      final degraded = _entry(
        id: 'draft',
        transcript:
            '[draft] Recording saved locally — transcribe when connected',
        localAudioPath: '/tmp/draft.m4a',
        reflection: const Reflection(
          mood: 'neutral',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      );

      expect(
        await CuriosityHookCoordinator.instance().persistAfterVoiceSave(
          savedEntry: degraded,
          allEntries: [degraded],
        ),
        isNull,
      );
    });
  });

  group('CuriosityHookGates', () {
    test('post-save card requires entry id and anchor text on hook', () {
      final hook = CuriosityHook(
        id: 'h1',
        entryId: 'e1',
        createdAt: DateTime.utc(2026, 6, 12),
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.returnWatch,
        dynamicPrompt: 'Come back when it shows up again.',
      );
      expect(hook.entryId.isNotEmpty && hook.primaryAnchor.isNotEmpty, isTrue);
      expect(
        hook.copyWith(entryId: '').entryId.isEmpty ||
            hook.copyWith(entryId: '').primaryAnchor.isEmpty,
        isTrue,
      );
    });

    test('post-save card respects V1 retention policy', () {
      final hook = CuriosityHook(
        id: 'h1',
        entryId: 'e1',
        createdAt: DateTime.utc(2026, 6, 12),
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.returnWatch,
        dynamicPrompt:
            'Come back when "said yes again" shows up again and say what changed.',
      );

      final expected = V1RetentionPolicy.showCuriosityPostSaveHooks;
      expect(
        CuriosityHookGates.shouldShowPostSaveCard(
          isPostSaveDone: true,
          hook: hook,
          isDegradedPostSave: false,
        ),
        expected,
      );
      expect(
        CuriosityHookGates.shouldShowPostSaveCard(
          isPostSaveDone: true,
          hook: hook,
          isDegradedPostSave: true,
        ),
        isFalse,
      );
    });
  });
}

class _FakeCuriosityNotificationScheduler
    extends CuriosityNotificationScheduler {
  _FakeCuriosityNotificationScheduler({
    this.grantPermissions = true,
    this.throwOnSchedule = false,
  });

  final bool grantPermissions;
  final bool throwOnSchedule;

  int initializeCalls = 0;
  int requestPermissionCalls = 0;
  int scheduleCalls = 0;
  CuriosityHook? lastScheduledHook;
  String? lastScheduledPromptBody;

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<bool> requestPermissions() async {
    requestPermissionCalls++;
    return grantPermissions;
  }

  @override
  Future<bool> scheduleCuriosityNotification(
    CuriosityHook hook, {
    Duration scheduleAfter =
        CuriosityNotificationScheduler.defaultScheduleAfter,
    String? promptBody,
  }) async {
    scheduleCalls++;
    lastScheduledHook = hook;
    lastScheduledPromptBody = promptBody;
    if (throwOnSchedule) {
      throw StateError('schedule failed');
    }
    return grantPermissions;
  }
}

class _FakeJournalStore implements CuriosityHookJournalStore {
  _FakeJournalStore(this.entries);

  final Map<String, JournalEntry> entries;

  @override
  Future<JournalEntry?> getEntryById(String entryId) async => entries[entryId];
}