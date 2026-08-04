import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_models.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_store.dart';
import 'package:voicememory_mobile/features/connectors/external_data_adapters.dart';
import 'package:voicememory_mobile/features/connectors/healthkit_connector.dart';
import 'package:voicememory_mobile/features/morning_briefing/morning_briefing_service.dart';
import 'package:voicememory_mobile/features/morning_briefing/morning_briefing_store.dart';
import 'package:voicememory_mobile/features/morning_briefing/morning_briefing_synthesis_service.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory directory;
  late _Fixture fixture;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('morning-briefing-test');
    fixture = await _Fixture.create(directory);
  });

  tearDown(() async {
    await fixture.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'aggregates yesterday, incomplete habits, health, and velocity',
    () async {
      await fixture.journal.save(
        JournalEntry(
          id: 'entry-yesterday',
          createdAt: DateTime(2026, 7, 26, 18),
          transcript: 'Launch planning launch pressure roadmap',
          durationSeconds: 180,
          reflection: Reflection.deterministicTranscriptOnly(
            transcript: 'Launch planning launch pressure roadmap',
            entryId: 'entry-yesterday',
          ),
        ),
      );
      await fixture.plans.upsert(
        ActionPlan(
          id: 'plan-1',
          clusterId: 'cluster-1',
          title: 'Launch calmly',
          targetOutcome: 'Ship',
          createdAt: DateTime.utc(2026, 7, 20),
          steps: [
            MicroHabitStep(
              id: 'habit-1',
              planId: 'plan-1',
              title: 'Review the roadmap',
              frequency: ActionPlanFrequency.daily(),
              targetNodeId: 'node-1',
              streakCount: 4,
            ),
          ],
        ),
      );
      await fixture.clusters.upsert(
        SemanticCluster(
          id: 'cluster-1',
          title: 'Product launch',
          category: SemanticClusterCategory.project,
          nodeIds: const ['node-1', 'node-2'],
          activityVelocity: .8,
          confidenceScore: .9,
        ),
      );

      final payload = await fixture.service.aggregate(
        DateTime(2026, 7, 27, 7, 10),
      );

      expect(payload.journalEntryCount, 1);
      expect(payload.journalMinutes, 3);
      expect(payload.topicSignals.first, 'launch');
      expect(payload.incompleteHabits.single.currentRun, 4);
      expect(payload.clusterSignals.single.velocityDelta, .8);
      expect(payload.sleepHours, 7.5);
      expect(payload.restingHeartRate, 58);
    },
  );

  test('does not trigger before 7 AM or during quiet hours', () async {
    expect(
      await fixture.service.isDue(now: DateTime(2026, 7, 27, 6, 59)),
      isFalse,
    );
    expect(await fixture.service.isDue(now: DateTime(2026, 7, 27, 7)), isTrue);
  });

  test('offline synthesis still persists a complete local briefing', () async {
    final briefing = await fixture.service.generateIfDue(
      force: true,
      now: DateTime(2026, 7, 27, 7),
    );

    expect(briefing, isNotNull);
    expect(briefing!.generatedOffline, isTrue);
    expect(briefing.sections, hasLength(3));
    expect(briefing.narration.split(RegExp(r'\s+')).length, greaterThan(140));
    expect(await fixture.store.forDay(DateTime(2026, 7, 27)), isNotNull);
    expect(fixture.scheduler.nextRun, isNotNull);
  });

  test('audio cache round trips without plaintext bytes on disk', () async {
    final audioFile = File('${directory.path}/isolated-audio.enc');
    final storage = EncryptedMorningBriefingAudioStorage(
      EncryptedJsonFileStore(
        file: audioFile,
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    final bytes = Uint8List.fromList('private-narration-bytes'.codeUnits);

    await storage.write('briefing-private', bytes);

    expect(await storage.read('briefing-private'), bytes);
    expect(
      await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
        audioFile,
        'private-narration-bytes',
      ),
      isTrue,
    );
  });
}

class _Fixture {
  _Fixture({
    required this.journal,
    required this.plans,
    required this.clusters,
    required this.store,
    required this.service,
    required this.scheduler,
  });

  final JournalStore journal;
  final ActionPlanStore plans;
  final SemanticClusterStore clusters;
  final MorningBriefingStore store;
  final MorningBriefingService service;
  final _FakeScheduler scheduler;

  static Future<_Fixture> create(Directory directory) async {
    final key = InMemoryPrivateDataEncryptionKeyStore();
    final journal = await JournalStore.open(
      '${directory.path}/journal.json',
      encryptAtRest: false,
      syncDeviceIdProvider: () async => 'test-device',
    );
    final plans = ActionPlanStore(
      storage: EncryptedJsonFileStore(
        file: File('${directory.path}/plans.enc'),
        keyStore: key,
      ),
    );
    final clusters = SemanticClusterStore(
      storage: EncryptedJsonFileStore(
        file: File('${directory.path}/clusters.enc'),
        keyStore: key,
      ),
    );
    final store = MorningBriefingStore(
      EncryptedJsonFileStore(
        file: File('${directory.path}/briefings.enc'),
        keyStore: key,
      ),
    );
    final audio = EncryptedMorningBriefingAudioStorage(
      EncryptedJsonFileStore(
        file: File('${directory.path}/audio.enc'),
        keyStore: key,
      ),
    );
    final scheduler = _FakeScheduler();
    final service = MorningBriefingService(
      journalStore: journal,
      actionPlanStore: plans,
      clusterStore: clusters,
      healthDataSource: _FakeHealthDataSource(),
      isHealthEnabled: () async => true,
      store: store,
      audioStorage: audio,
      synthesizer: const LocalMorningBriefingAiService(),
      scheduler: scheduler,
      clock: () => DateTime(2026, 7, 27, 7, 5),
    );
    return _Fixture(
      journal: journal,
      plans: plans,
      clusters: clusters,
      store: store,
      service: service,
      scheduler: scheduler,
    );
  }

  Future<void> dispose() async {
    plans.dispose();
    clusters.dispose();
    await store.dispose();
  }
}

class _FakeHealthDataSource implements HealthDataSource {
  @override
  Future<bool> authorize() async => true;

  @override
  Future<HealthDailySample> readDay(DateTime day) async => HealthDailySample(
    day: day,
    sleepHours: 7.5,
    restingHeartRate: 58,
    steps: 3000,
  );
}

class _FakeScheduler implements MorningBriefingScheduler {
  DateTime? nextRun;

  @override
  Future<void> cancel() async => nextRun = null;

  @override
  Future<void> schedule(DateTime nextLocalRun) async {
    nextRun = nextLocalRun;
  }
}
