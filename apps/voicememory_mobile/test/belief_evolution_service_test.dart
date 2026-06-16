import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_service.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'dart:io';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String observation,
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript:
        'Transcript for $id with enough characters to count as evidence.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: observation,
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('refreshFromEntries tracks first and current belief versions', () async {
    final dir = await Directory.systemTemp.createTemp('belief_evo');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = BeliefEvolutionService(BeliefEvolutionStore(prefs));

    final entries = List.generate(
      5,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2025, 6, i + 1),
        observation: i < 3
            ? 'I need approval from others.'
            : 'I trust my own judgment now.',
      ),
    );

    final legacy = ArchiveStateSnapshot(
      belief: 'I need approval.',
      confidence: 40,
      reputation: 'low',
      evidenceCount: 2,
      lifeAreas: const [],
      timestamp: DateTime(2025, 1, 1).toIso8601String(),
    );

    final state = await service.refreshFromEntries(
      entries: entries,
      legacySnapshot: legacy,
    );

    expect(state.firstBelief?.beliefText, contains('approval'));
    expect(state.currentBelief?.beliefText, contains('judgment'));
    expect(state.versions.length, greaterThanOrEqualTo(2));
    expect(state.currentBelief!.confidence, greaterThan(0));
    expect(state.currentBelief!.supportingEntryIds, isNotEmpty);
  });

  test('buildTimeline produces belief and evidence blocks', () async {
    final dir = await Directory.systemTemp.createTemp('belief_evo_tl');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = BeliefEvolutionService(BeliefEvolutionStore(prefs));

    final entries = List.generate(
      5,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2025, 6, i + 1),
        observation: 'Observation $i with enough detail for the archive.',
      ),
    );

    final state = await service.refreshFromEntries(entries: entries);
    final timeline = service.buildTimeline(state: state, entries: entries);

    expect(timeline.blocks, isNotEmpty);
    expect(timeline.blocks.first.evidence, isNotEmpty);
    expect(timeline.firstBelief, isNotNull);
    expect(timeline.currentBelief, isNotNull);
  });

  test('toSyncPayload includes schema version', () async {
    final dir = await Directory.systemTemp.createTemp('belief_evo_sync');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final service = BeliefEvolutionService(BeliefEvolutionStore(prefs));
    final state = await service.loadState();
    final payload = service.toSyncPayload(state);
    expect(payload['schemaVersion'], 1);
    expect(payload['evolution'], isA<Map<String, dynamic>>());
  });
}
