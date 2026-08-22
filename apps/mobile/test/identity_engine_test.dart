import 'package:archiveme_mobile/features/identity_engine/identity_engine.dart';
import 'package:archiveme_mobile/features/identity_engine/identity_models.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_track.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String text,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$text — padding for eligible transcript length requirement.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: text,
      concreteObservation: text,
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> _fiveEntries() {
  return List.generate(
    5,
    (i) => _entry(
      id: 'e$i',
      at: DateTime(2025, 6, i + 1),
      text: i < 2
          ? 'I need approval from others at work'
          : 'I am growing in confidence about my career',
      themes: i < 2 ? const ['approval'] : const ['confidence', 'career'],
    ),
  );
}

void main() {
  test('returns empty profile below archive evidence threshold', () {
    final profile = const IdentityEngine().build(
      entries: [
        _entry(
          id: '1',
          at: DateTime(2026),
          text: 'I need approval from others',
        ),
      ],
    );
    expect(profile.hasMinimumArchiveEvidence, isFalse);
    expect(profile.hasTraits, isFalse);
  });

  test('builds evidence-backed traits without fabrication', () {
    final profile = const IdentityEngine().build(entries: _fiveEntries());
    final allTraits = [
      ...profile.currentTraits,
      ...profile.emergingTraits,
      ...profile.decliningTraits,
    ];

    expect(profile.hasMinimumArchiveEvidence, isTrue);
    expect(profile.hasTraits, isTrue);
    expect(allTraits.any((t) => t.evidenceCount >= 2), isTrue);
    expect(allTraits.every((t) => t.supportingRecordingIds.isNotEmpty), isTrue);
    expect(
      allTraits.any((t) => t.title.toLowerCase().contains('approval')),
      isTrue,
    );
  });

  test('confidence trait uses becoming copy when trend is up', () {
    final entries = [
      ...List.generate(
        3,
        (i) => _entry(
          id: 'old$i',
          at: DateTime(2025, 1, i + 1),
          text: 'approval seeking at work',
          themes: const ['approval'],
        ),
      ),
      ...List.generate(
        5,
        (i) => _entry(
          id: 'new$i',
          at: DateTime(2026, 1, i + 1),
          text: 'I feel confident in my judgment',
          themes: const ['confidence'],
        ),
      ),
    ];

    final profile = const IdentityEngine().build(entries: entries);
    final confident = profile.emergingTraits
        .followedBy(profile.currentTraits)
        .where((t) => t.title.contains('confident'))
        .toList();
    expect(confident, isNotEmpty);
  });

  test('IdentityProfile round-trips JSON', () {
    final profile = IdentityProfile(
      currentTraits: [
        const IdentityTrait(
          id: 'theme:avoidance',
          title: 'You avoid conflict',
          confidence: 70,
          evidenceCount: 3,
          supportingRecordingIds: ['a', 'b'],
          supportingQuotes: ['I avoid hard talks'],
          trend: ThemeTrend.stable,
        ),
      ],
      emergingTraits: const [],
      decliningTraits: const [],
      lastUpdated: DateTime.utc(2026),
      hasMinimumArchiveEvidence: true,
      evidenceReflectionCount: 5,
    );
    final parsed = IdentityProfile.fromJson(profile.toJson());
    expect(parsed.currentTraits.first.title, 'You avoid conflict');
  });
}