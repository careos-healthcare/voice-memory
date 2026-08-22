import 'dart:io';

import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_service.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_engine.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String transcript,
  String observation = '',
}) {
  final obs = observation.isNotEmpty ? observation : transcript;
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: obs,
      repeatedSignal: '',
    ),
  );
}

void main() {
  const engine = BeliefLifecycleEngine();

  test('current lifecycle has first and last seen', () {
    final entries = [
      _entry(
        id: 'a',
        at: DateTime.utc(2026, 1, 10),
        transcript:
            'I am not ready to have difficult conversations at work yet today.',
      ),
      _entry(
        id: 'b',
        at: DateTime.utc(2026, 3, 14),
        transcript:
            'I am still not ready for that conversation with my manager.',
      ),
      for (var i = 0; i < 6; i++)
        _entry(
          id: 'f$i',
          transcript:
              'Unrelated notes about cooking travel music and weekend plans only.',
          at: DateTime.utc(2026, 3, 20 + i),
        ),
    ];

    final view = engine.build(
      entries: entries,
      activeStatement: "I'm not ready for difficult conversations",
    );

    expect(view.current, isNotNull);
    expect(view.current!.firstSeen, isNotNull);
    expect(view.current!.lastSeen, isNotNull);
    expect(
      view.current!.firstSeen!.isBefore(view.current!.lastSeen!) ||
          view.current!.firstSeen == view.current!.lastSeen,
      isTrue,
    );
    expect(view.current!.events, isNotEmpty);
    expect(
      view.current!.events.first.phase,
      BeliefLifecyclePhase.firstAppearance,
    );
  });

  test('retired belief from evolution shows no longer detected', () async {
    final dir = await Directory.systemTemp.createTemp('belief_lc_');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final evolution = BeliefEvolutionService.fromPrefs(prefs);

    final entries = List.generate(
      6,
      (i) => _entry(
        id: 'e$i',
        at: DateTime.utc(2026, 1, 10 + i),
        transcript: i < 3
            ? 'I need approval from others before I speak up at work.'
            : 'I trust my own judgment when I speak at work now.',
        observation: i < 3
            ? 'I need approval from others.'
            : 'I trust my own judgment now.',
      ),
    );

    final evo = await evolution.refreshFromEntries(
      entries: entries,
      legacySnapshot: ArchiveStateSnapshot(
        belief: 'I need approval.',
        confidence: 40,
        reputation: 'low',
        evidenceCount: 2,
        lifeAreas: const [],
        timestamp: '2026-01-01T00:00:00.000Z',
      ),
    );

    final view = engine.build(
      entries: entries,
      activeStatement: 'I trust my own judgment now.',
      evolution: evo,
    );

    expect(view.current?.statement, contains('judgment'));
    expect(view.retired, isNotEmpty);
    final old = view.retired.firstWhere(
      (r) => r.statement.toLowerCase().contains('approval'),
      orElse: () => view.retired.first,
    );
    expect(
      old.status,
      anyOf(
        BeliefLifecycleStatus.noLongerDetected,
        BeliefLifecycleStatus.dormant,
        BeliefLifecycleStatus.weakening,
      ),
    );
    expect(
      old.events.any((e) => e.phase == BeliefLifecyclePhase.firstAppearance),
      isTrue,
    );
  });

  test(
    'retired I am not ready shows no longer detected with last seen',
    () async {
      final dir = await Directory.systemTemp.createTemp('belief_lc_ready_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);

      final lastAt = DateTime.utc(2026, 3, 14);
      final entries = [
        _entry(
          id: 'old1',
          at: DateTime.utc(2026, 1, 5),
          transcript: "I'm not ready to have that conversation yet.",
          observation: "I'm not ready",
        ),
        _entry(
          id: 'old2',
          at: lastAt,
          transcript: "I'm not ready — I keep postponing it.",
          observation: "I'm not ready",
        ),
        for (var i = 0; i < 8; i++)
          _entry(
            id: 'new$i',
            at: DateTime.utc(2026, 4, 1 + i),
            transcript:
                'I finally spoke up clearly at work and felt steady afterward.',
            observation: 'I finally spoke up clearly at work.',
          ),
      ];

      final evo = await evolution.refreshFromEntries(
        entries: entries,
        legacySnapshot: ArchiveStateSnapshot(
          belief: "I'm not ready",
          confidence: 50,
          reputation: 'developing',
          evidenceCount: 2,
          lifeAreas: const [],
          timestamp: '2026-01-01T00:00:00.000Z',
        ),
      );

      final view = engine.build(
        entries: entries,
        activeStatement: 'I finally spoke up clearly at work.',
        evolution: evo,
      );

      final retired = view.retired.where(
        (r) => r.statement.toLowerCase().contains('not ready'),
      );
      expect(retired, isNotEmpty);
      final gone = retired.first;
      expect(gone.status, BeliefLifecycleStatus.noLongerDetected);
      expect(gone.lastSeen, lastAt);
      expect(formatUserFacingDate(lastAt), '14 March 2026');
      expect(
        gone.events.any((e) => e.phase == BeliefLifecyclePhase.death),
        isTrue,
      );
    },
  );

  test('status labels cover all enums', () {
    for (final s in BeliefLifecycleStatus.values) {
      expect(BeliefLifecycleCopy.statusLabelFor(s), isNotEmpty);
    }
  });
}