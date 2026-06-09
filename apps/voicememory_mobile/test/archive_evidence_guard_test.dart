import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_challenge/archive_challenge_engine.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:voicememory_mobile/features/daily_discoveries/daily_discovery_engine.dart';
import 'package:voicememory_mobile/features/living_archive/archive_was_wrong_engine.dart';
import 'package:voicememory_mobile/features/living_archive/belief_under_review_engine.dart';
import 'package:voicememory_mobile/features/living_archive/most_important_insight_engine.dart';
import 'package:voicememory_mobile/features/living_archive/what_changed_today_engine.dart';
import 'package:voicememory_mobile/features/weekly_story/weekly_story_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2025, 5, int.parse(id) + 1),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: 'pattern',
      concreteObservation: '',
      repeatedSignal: 'signal',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  test('fresh install has zero eligible evidence', () {
    expect(ArchiveEvidenceGuard.eligibleReflectionCount([]), 0);
    expect(ArchiveEvidenceGuard.hasMinimumEvidence([]), isFalse);
  });

  test('insight engines return null without minimum evidence', () {
    const empty = <JournalEntry>[];
    const engine = DailyDiscoveryEngine();
    expect(
      engine.detectDiscovery(
        entries: empty,
        state: null,
        baseline: null,
        viewedIds: const {},
      ),
      isNull,
    );
    expect(const ArchiveChallengeEngine().detectChallenge(entries: empty), isNull);
    expect(const ArchiveWasWrongEngine().detect(entries: empty), isNull);
    expect(const BeliefUnderReviewEngine().build(entries: empty), isNull);
    expect(const WhatChangedTodayEngine().build(entries: empty), isNull);
    expect(
      const MostImportantInsightEngine().pick(entries: empty),
      isNull,
    );
    expect(const WeeklyStoryEngine().build(entries: empty), isNull);
  });

  test('short transcripts never count as evidence', () {
    final entries = List.generate(
      6,
      (i) => _entry('$i', 'too short'),
    );
    expect(ArchiveEvidenceGuard.hasMinimumEvidence(entries), isFalse);
  });
}
