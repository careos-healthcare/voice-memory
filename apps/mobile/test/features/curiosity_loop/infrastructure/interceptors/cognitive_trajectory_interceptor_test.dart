import 'package:archiveme_mobile/features/curiosity_loop/application/curiosity_hook_journal_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';
import 'package:archiveme_mobile/features/curiosity_loop/infrastructure/interceptors/cognitive_trajectory_interceptor.dart';
import 'package:archiveme_mobile/features/curiosity_loop/presentation/models/telemetry_data_point.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/clinical_trajectory_history_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/cognitive_trajectory_telemetry.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reflection = Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  );

  const sourceBiomarkers = CognitiveBiomarkers(
    lexicalDiversity: 0.40,
    cohesionDrift: 0.85,
    emotionalVolatility: 0.50,
  );

  final hook = CuriosityHook(
    id: 'hook_1',
    entryId: 'response_entry',
    createdAt: DateTime.utc(2026, 6, 12, 10),
    primaryAnchor: 'work pressure',
    hookType: CuriosityHookType.blocker,
    dynamicPrompt: 'What shifted since yesterday?',
    sourceEntryId: 'source_entry',
    isMemoryRecallCheck: true,
  );

  JournalEntry entry({
    required String id,
    String? parentHookId,
    CognitiveBiomarkers? biomarkers,
    bool wasGrounded = false,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 6, 12, 12),
      transcript: 'Sample transcript with enough words.',
      durationSeconds: 20,
      reflection: reflection,
      biomarkers: biomarkers,
      parentHookId: parentHookId,
      wasGrounded: wasGrounded,
    );
  }

  group('CognitiveTrajectoryInterceptor', () {
    late _FakeHookRepository hookRepository;
    late _FakeJournalStore journalStore;
    late _FakeTrajectoryHistoryStore trajectoryHistoryStore;
    late List<Map<String, Object>> telemetryEvents;
    late List<CognitiveTrajectoryRecord> assessments;

    setUp(() {
      hookRepository = _FakeHookRepository(hooks: {'hook_1': hook});
      journalStore = _FakeJournalStore(
        entries: {
          'source_entry': entry(
            id: 'source_entry',
            biomarkers: sourceBiomarkers,
          ),
        },
      );
      trajectoryHistoryStore = _FakeTrajectoryHistoryStore();
      telemetryEvents = [];
      assessments = [];
    });

    CognitiveTrajectoryInterceptor buildInterceptor() {
      return CognitiveTrajectoryInterceptor(
        hookRepository: hookRepository,
        journalStore: journalStore,
        trajectoryHistoryStore: trajectoryHistoryStore,
        telemetry: CognitiveTrajectoryTelemetry(
          sink: (event, meta) => telemetryEvents.add({'event': event, ...meta}),
        ),
        onAssessment: assessments.add,
        clock: () => DateTime.utc(2026, 6, 12, 16),
      );
    }

    test('ignores entries without a parent hook id', () async {
      final interceptor = buildInterceptor();

      await interceptor.onEntrySaved(
        entry(
          id: 'plain_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.55,
            cohesionDrift: 0.40,
            emotionalVolatility: 0.30,
          ),
        ),
      );

      expect(telemetryEvents, isEmpty);
      expect(assessments, isEmpty);
    });

    test(
      'records recovering trajectory when drift drops significantly',
      () async {
        final interceptor = buildInterceptor();

        await interceptor.onEntrySaved(
          entry(
            id: 'response_entry',
            parentHookId: 'hook_1',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.42,
              cohesionDrift: 0.60,
              emotionalVolatility: 0.40,
            ),
          ),
        );

        expect(assessments, hasLength(1));
        expect(
          assessments.single.assessment.direction,
          CognitiveDirection.recovering,
        );
        expect(assessments.single.assessment.driftDelta, closeTo(-0.25, 0.001));
        expect(
          telemetryEvents.single['event'],
          CognitiveTrajectoryTelemetry.trajectoryAssessedEvent,
        );
        expect(telemetryEvents.single['direction'], 'recovering');
        expect(telemetryEvents.single['hook_id'], 'hook_1');
        expect(telemetryEvents.single['source_entry_id'], 'source_entry');
        expect(trajectoryHistoryStore.records, hasLength(1));
        expect(
          trajectoryHistoryStore.records.single.direction,
          CognitiveDirection.recovering,
        );
      },
    );

    test(
      'records declining trajectory when drift worsens significantly',
      () async {
        journalStore.entries['source_entry'] = entry(
          id: 'source_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.60,
            cohesionDrift: 0.30,
            emotionalVolatility: 0.20,
          ),
        );
        final interceptor = buildInterceptor();

        await interceptor.onEntrySaved(
          entry(
            id: 'response_entry',
            parentHookId: 'hook_1',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.58,
              cohesionDrift: 0.50,
              emotionalVolatility: 0.40,
            ),
          ),
        );

        expect(
          assessments.single.assessment.direction,
          CognitiveDirection.declining,
        );
        expect(assessments.single.assessment.driftDelta, closeTo(0.20, 0.001));
        expect(telemetryEvents.single['direction'], 'declining');
      },
    );

    test(
      'records stagnant trajectory when deltas stay within bounds',
      () async {
        journalStore.entries['source_entry'] = entry(
          id: 'source_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.50,
            cohesionDrift: 0.40,
            emotionalVolatility: 0.30,
          ),
        );
        final interceptor = buildInterceptor();

        await interceptor.onEntrySaved(
          entry(
            id: 'response_entry',
            parentHookId: 'hook_1',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.52,
              cohesionDrift: 0.45,
              emotionalVolatility: 0.32,
            ),
          ),
        );

        expect(
          assessments.single.assessment.direction,
          CognitiveDirection.stagnant,
        );
        expect(telemetryEvents.single['direction'], 'stagnant');
      },
    );

    test('does not emit when source entry biomarkers are missing', () async {
      journalStore.entries['source_entry'] = entry(id: 'source_entry');
      final interceptor = buildInterceptor();

      await interceptor.onEntrySaved(
        entry(
          id: 'response_entry',
          parentHookId: 'hook_1',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.52,
            cohesionDrift: 0.45,
            emotionalVolatility: 0.32,
          ),
        ),
      );

      expect(telemetryEvents, isEmpty);
      expect(assessments, isEmpty);
    });

    test(
      'tags grounded hook responses in telemetry and history records',
      () async {
        final interceptor = buildInterceptor();

        await interceptor.onEntrySaved(
          entry(
            id: 'response_entry',
            parentHookId: 'hook_1',
            wasGrounded: true,
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.42,
              cohesionDrift: 0.60,
              emotionalVolatility: 0.40,
            ),
          ),
        );

        expect(telemetryEvents.single['wasGrounded'], isTrue);
        expect(assessments.single.wasGrounded, isTrue);
        expect(trajectoryHistoryStore.records.single.wasGrounded, isTrue);
      },
    );

    test(
      'resolves source entry from hook entry id when sourceEntryId is absent',
      () async {
        hookRepository.hooks['hook_entry_only'] = CuriosityHook(
          id: 'hook_entry_only',
          entryId: 'source_entry',
          createdAt: DateTime.utc(2026, 6, 12, 10),
          primaryAnchor: 'work pressure',
          hookType: CuriosityHookType.blocker,
          dynamicPrompt: 'What shifted since yesterday?',
        );
        final interceptor = buildInterceptor();

        await interceptor.onEntrySaved(
          entry(
            id: 'response_entry',
            parentHookId: 'hook_entry_only',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.42,
              cohesionDrift: 0.60,
              emotionalVolatility: 0.40,
            ),
          ),
        );

        expect(assessments, hasLength(1));
        expect(assessments.single.sourceEntryId, 'source_entry');
      },
    );
  });
}

class _FakeHookRepository implements CuriosityHookRepository {
  _FakeHookRepository({required this.hooks});

  final Map<String, CuriosityHook> hooks;

  @override
  Future<CuriosityHook?> fetchById(String hookId) async => hooks[hookId];

  @override
  Future<CuriosityHook?> fetchLatestUnconsumed() async => null;

  @override
  Future<List<CuriosityHook>> loadAll() async => hooks.values.toList();

  @override
  Future<List<CuriosityHookType>> recentHookTypes({int limit = 4}) async =>
      const [];

  @override
  Future<void> markConsumed(String hookId) async {}

  @override
  Future<void> saveHook(CuriosityHook hook) async {
    hooks[hook.id] = hook;
  }
}

class _FakeJournalStore implements CuriosityHookJournalStore {
  _FakeJournalStore({required this.entries});

  final Map<String, JournalEntry> entries;

  @override
  Future<JournalEntry?> getEntryById(String entryId) async => entries[entryId];
}

class _FakeTrajectoryHistoryStore implements ClinicalTrajectoryHistoryStore {
  final List<StoredTrajectoryRecord> records = [];

  @override
  Future<bool> appendRecord(StoredTrajectoryRecord record) async {
    records.add(record);
    return true;
  }

  @override
  Future<List<TelemetryDataPoint>> loadRecent({
    Duration window = const Duration(days: 7),
    DateTime? now,
  }) async {
    return records.map((record) => record.toTelemetryDataPoint()).toList();
  }
}