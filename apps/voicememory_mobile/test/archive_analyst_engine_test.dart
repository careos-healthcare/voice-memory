import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_engine.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_gate.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_service.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

JournalEntry _entry(String id, String transcript, {DateTime? at}) {
  return JournalEntry(
    id: id,
    createdAt: at ?? DateTime.utc(2026, 1, id.hashCode % 28 + 1),
    transcript: transcript,
    durationSeconds: 40,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 3,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: transcript,
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

List<JournalEntry> _fiftyPlusEntries() {
  final entries = <JournalEntry>[
    for (var i = 0; i < 30; i++)
      _entry(
        'avoid$i',
        'I avoid difficult conversations when conflict feels overwhelming at work or home.',
        at: DateTime.utc(2026, 1, (i % 20) + 1),
      ),
    for (var i = 0; i < 25; i++)
      _entry(
        'career$i',
        'My career and what my manager expects dominate how I plan my week.',
        at: DateTime.utc(2026, 3, (i % 20) + 1),
      ),
  ];
  return entries;
}

void main() {
  group('ArchiveAnalystEngine', () {
    test('insufficient below 50', () async {
      final dir = await Directory.systemTemp.createTemp('analyst_gate_');
      final prefs = await MobilePrefsStore.open('${dir.path}/p.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);
      final entries = List.generate(
        10,
        (i) => _entry('e$i', 'This is a long enough transcript about work and stress today.'),
      );
      final report = await const ArchiveAnalystEngine().build(
        entries: entries,
        evolutionService: evolution,
      );
      expect(report.hasReport, isFalse);
      expect(report.level, ArchiveAnalystLevel.insufficient);
    });

    test('builds full report at 50+', () async {
      final dir = await Directory.systemTemp.createTemp('analyst_eng_');
      final prefs = await MobilePrefsStore.open('${dir.path}/p.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);
      final entries = _fiftyPlusEntries();

      final report = await const ArchiveAnalystEngine().build(
        entries: entries,
        evolutionService: evolution,
      );

      expect(report.hasReport, isTrue);
      expect(report.eligibleReflectionCount, greaterThanOrEqualTo(50));
      expect(report.currentBeliefs, isNotEmpty);
      expect(report.competingBeliefs, isNotEmpty);
      expect(report.debates, isNotEmpty);
      expect(report.evidenceSummary.dateSpanLabel, isNot('—'));
    });

    test('level 2 at 100 entries', () async {
      final dir = await Directory.systemTemp.createTemp('analyst_l2_');
      final prefs = await MobilePrefsStore.open('${dir.path}/p.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);
      final entries = [
        ..._fiftyPlusEntries(),
        ..._fiftyPlusEntries().map(
          (e) => _entry('${e.id}_b', e.transcript, at: e.createdAt.add(const Duration(days: 30))),
        ),
      ];

      final report = await const ArchiveAnalystEngine().build(
        entries: entries,
        evolutionService: evolution,
      );

      expect(report.level, ArchiveAnalystLevel.level2);
      expect(report.currentBeliefs.length, lessThanOrEqualTo(6));
    });
  });
}
