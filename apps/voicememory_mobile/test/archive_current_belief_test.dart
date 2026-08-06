import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_current_belief_engine.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_current_belief_gates.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_display_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> get _confirmedThreeEntries => [
  _entry(
    '1',
    'I had no capacity but I said yes again to the extra meeting today.',
  ),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
  ),
];

void main() {
  group('ArchiveCurrentBeliefEngine', () {
    test('builds provisional belief surface after first proof', () {
      final surface = ArchiveCurrentBeliefEngine.build(
        entries: _confirmedThreeEntries,
        viewingConfirmedRepeatOrTimeline: true,
      );

      expect(surface, isNotNull);
      expect(surface!.isPrimaryAfterFirstProof, isTrue);
      expect(surface.headline, ArchiveBeliefSurfaceCopy.headline);
      expect(surface.evidencePhrases, isNotEmpty);
      expect(surface.evidencePhrases.length, lessThanOrEqualTo(3));
      expect(surface.watchingNextLine, isNotNull);
      expect(surface.whatChangedSummary, isNotNull);
      expect(ArchiveDisplayCopyGuard.passes(surface.beliefSummary), isTrue);
    });

    test('hidden before first proof foundation', () {
      expect(
        ArchiveCurrentBeliefEngine.build(
          entries: [
            _entry('1', 'A quiet lunch with a friend today.'),
            _entry('2', 'Another unrelated note about errands.'),
          ],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('copy avoids therapy and personality claims', () {
      final haystack = [
        ArchiveBeliefSurfaceCopy.headline,
        ArchiveBeliefSurfaceCopy.evidenceLabel,
        ArchiveBeliefSurfaceCopy.whatChangedLabel,
        ArchiveBeliefSurfaceCopy.watchingLabel,
        ArchiveBeliefSurfaceCopy.beliefFallback,
      ].join(' ').toLowerCase();

      expect(haystack, isNot(contains('therapy')));
      expect(haystack, isNot(contains('diagnosis')));
      expect(haystack, isNot(contains('about you')));
      expect(haystack, isNot(contains('you always')));
    });

    test('uses provisional evidence language not conclusions', () {
      final copy = [
        ArchiveBeliefSurfaceCopy.headline,
        ArchiveBeliefSurfaceCopy.evidenceLabel,
        ArchiveBeliefSurfaceCopy.watchingLabel,
        ArchiveBeliefSurfaceCopy.watchingFallback,
        ArchiveBeliefSurfaceCopy.previewBadge,
      ].join(' ').toLowerCase();

      expect(copy, contains('based on these moments'));
      expect(copy, contains('still watching'));
      expect(copy, contains('evidence'));
      expect(copy, isNot(contains('this means')));
      for (final line in [
        ArchiveBeliefSurfaceCopy.headline,
        ArchiveBeliefSurfaceCopy.evidenceLabel,
        ArchiveBeliefSurfaceCopy.watchingLabel,
        ArchiveBeliefSurfaceCopy.previewBadge,
      ]) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('ArchiveCurrentBeliefGates', () {
    test('shows after first proof with current belief surface', () {
      final surface = ArchiveCurrentBeliefEngine.build(
        entries: _confirmedThreeEntries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(
        ArchiveCurrentBeliefGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasConfirmedRepeatFoundation:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                _confirmedThreeEntries,
              ),
          hasCurrentBeliefSurface:
              surface?.isPrimaryAfterFirstProof == true && surface!.shouldShow,
        ),
        isTrue,
      );
    });

    test('hidden before entry 3', () {
      expect(
        ArchiveCurrentBeliefGates.shouldShow(
          loaded: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasConfirmedRepeatFoundation: false,
          hasCurrentBeliefSurface: true,
        ),
        isFalse,
      );
    });
  });

  group('Patterns post-proof stack order', () {
    test('primary surfaces follow deterministic order constants', () {
      expect(PatternsPostProofStackOrder.primarySurfacesAfterFirstProof, [
        PatternsPostProofStackOrder.archiveCurrentBelief,
        PatternsPostProofStackOrder.whatChangedSinceLastTime,
        PatternsPostProofStackOrder.earlyEvidenceTimeline,
      ]);
    });

    test('ArchiveCurrentBelief leads WhatChanged and timeline on Patterns', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      const stackAnchor =
          'if (showArchiveCurrentBelief &&\n                    archiveBeliefSurfaceCandidate.shouldShow)';
      final stackStart = source.indexOf(stackAnchor);
      expect(stackStart, greaterThan(0));
      final stack = source.substring(stackStart);
      final belief = stack.indexOf('ArchiveBeliefSurfaceCard');
      final whatChanged = stack.indexOf(
        '_buildWhatChangedSinceLastTimeWidgets',
      );
      final timeline = stack.indexOf('EarlyEvidenceTimelineCard');
      final privateReport = stack.indexOf('PrivateArchiveReportCard');
      final proBridge = stack.indexOf('ArchiveIntelligenceProBridgeCard');

      expect(belief, greaterThan(0));
      expect(whatChanged, greaterThan(belief));
      expect(timeline, greaterThan(whatChanged));
      expect(privateReport, greaterThan(timeline));
      expect(proBridge, greaterThan(privateReport));
    });

    test('timeline dedup suppresses duplicate helpful action card', () {
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: true,
        changeProofVisible: false,
        proBridgeVisible: false,
        helpfulActionAppearedVisible: true,
        timelineShowsHelpfulAction: true,
      );

      expect(layout.effectiveHelpfulActionAppearedVisible, isFalse);
    });

    test('change timeline dedup suppresses duplicate pattern changed card', () {
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: true,
        changeProofVisible: false,
        proBridgeVisible: false,
        patternChangedVisible: true,
        changeTimelineShowsChanged: true,
      );

      expect(layout.effectivePatternChangedVisible, isFalse);
    });
  });
}
