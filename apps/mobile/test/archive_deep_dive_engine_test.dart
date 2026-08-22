import 'dart:io';

import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_engine.dart';
import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_gate.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 1, id.hashCode % 25 + 1, 12),
    transcript: transcript,
    durationSeconds: 40,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 3,
      recurringThemes: themes,
      exactLanguagePattern: transcript.substring(
        0,
        transcript.length.clamp(0, 40),
      ),
      concreteObservation: transcript.length >= 16 ? transcript : '',
      repeatedSignal: themes.isNotEmpty ? themes.first : '',
    ),
  );
}

void main() {
  group('ArchiveDeepDiveEngine', () {
    test('returns null when V1 has no belief', () async {
      final dir = await Directory.systemTemp.createTemp('deep_dive_test_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);
      final entries = [_entry(id: 'a', transcript: 'short')];
      final v1 = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: evolution,
      );
      expect(const ArchiveDeepDiveEngine().build(v1: v1), isNull);
    });

    test('builds why, counter-evidence, and inquiries when gated', () async {
      final dir = await Directory.systemTemp.createTemp('deep_dive_test2_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);

      final entries = <JournalEntry>[
        for (var i = 0; i < 6; i++)
          _entry(
            id: 'avoid$i',
            transcript:
                'I avoid difficult conversations because conflict feels overwhelming at work.',
            themes: const ['relationships'],
          ),
        _entry(
          id: 'rel',
          transcript:
              'Relationships matter most to me but I rarely talk about them in recordings.',
          themes: const ['relationships'],
        ),
        for (var i = 0; i < 6; i++)
          _entry(
            id: 'work$i',
            transcript:
                'My career and manager expectations dominate my thoughts every single day.',
            themes: const ['career'],
          ),
      ];

      final v1 = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: evolution,
      );
      expect(ArchiveDeepDiveGate.canOpenDeepDive(v1), isTrue);

      final dive = const ArchiveDeepDiveEngine().build(v1: v1);
      expect(dive, isNotNull);
      expect(dive!.beliefStatement, isNotEmpty);
      expect(dive.why.evidenceCount, greaterThanOrEqualTo(5));
      expect(dive.why.excerptLines, isNotEmpty);
      expect(dive.counterEvidence.forExcerpts, isNotEmpty);
      expect(dive.inquiryQuestions, isNotEmpty);
      expect(dive.inquiryQuestions.any((q) => q.id == 'if_false'), isTrue);
      expect(dive.history.thenSnapshot.excerpt, isNotEmpty);
      expect(dive.history.nowSnapshot.excerpt, isNotEmpty);
      expect(dive.timeline.firstMention, isNotNull);
    });
  });
}