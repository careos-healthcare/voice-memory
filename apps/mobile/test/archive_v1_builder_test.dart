import 'dart:io';

import 'package:archiveme_mobile/features/archive_v1/archive_theme_gap_engine.dart';
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
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 1, id.hashCode % 28 + 1, 12),
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
  group('ArchiveThemeGapEngine', () {
    test('returns no gaps below minimum eligible count', () {
      final entries = List.generate(
        3,
        (i) => _entry(
          id: 'e$i',
          transcript:
              'Relationships matter most to me and my health is important today.',
        ),
      );
      final gaps = const ArchiveThemeGapEngine().build(entries);
      expect(gaps, isEmpty);
    });

    test('surfaces theme gap when importance claimed but low frequency', () {
      final entries = <JournalEntry>[
        for (var i = 0; i < 8; i++)
          _entry(
            id: 'work$i',
            transcript:
                'I keep thinking about my career and what my manager expects from me at work.',
            themes: const ['career'],
          ),
        _entry(
          id: 'rel1',
          transcript:
              'Relationships matter most to me but I am not sure how to show up for people.',
          themes: const ['relationships'],
        ),
      ];
      final gaps = const ArchiveThemeGapEngine().build(entries);
      expect(gaps, isNotEmpty);
      expect(gaps.first.youSay, contains('Relationships'));
      expect(gaps.first.but, contains('%'));
    });
  });

  group('ArchiveV1Builder', () {
    test('hasMinimumEvidence false yields empty belief', () async {
      final dir = await Directory.systemTemp.createTemp('archive_v1_test_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);

      final entries = [_entry(id: 'a', transcript: 'short')];
      final view = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: evolution,
      );
      expect(view.hasMinimumEvidence, isFalse);
      expect(view.belief, isNull);
    });

    test('builds belief when threshold met', () async {
      final dir = await Directory.systemTemp.createTemp('archive_v1_test2_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final evolution = BeliefEvolutionService.fromPrefs(prefs);

      final entries = List.generate(
        5,
        (i) => _entry(
          id: 'long$i',
          transcript:
              'I keep avoiding difficult conversations at work and it matters to my career growth.',
          themes: const ['career', 'avoidance'],
        ),
      );
      final view = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: evolution,
      );
      expect(view.hasMinimumEvidence, isTrue);
      expect(view.belief, isNotNull);
      expect(view.lifecycle.current, isNotNull);
      expect(view.lifecycle.current!.firstSeen, isNotNull);
      expect(view.changeFeed.hasBaseline, isFalse);
    });
  });
}