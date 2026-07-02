import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/archive_change_timeline_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_change_timeline_engine.dart';
import 'package:voicememory_mobile/features/early_archive/archive_change_timeline_gates.dart';
import 'package:voicememory_mobile/features/early_archive/archive_change_timeline_model.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/helpful_action_appeared_copy.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_change_timeline_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRelatedRepeatEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _fourRelatedRepeatEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fourWithHelpfulAction() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'Same yes pattern came back but I paused before replying this time.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fiveWithSofterReturn() => [
      ..._fourRelatedRepeatEntries(),
      _entry(
        id: 'e5',
        transcript:
            'Same yes pattern came back but it felt less urgent and easier to stop.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

void main() {
  group('ArchiveChangeTimelineEngine', () {
    test('title is Evidence timeline', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      expect(timeline!.title, ArchiveChangeTimelineCopy.title);
      expect(timeline.subtitle, ArchiveChangeTimelineCopy.subtitle);
    });

    test('labels render in clear order when evidence exists', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fiveWithSofterReturn(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e5',
            choice: RepeatReturnCheckChoice.softer,
            entryCountAtCapture: 5,
            createdAt: DateTime(2026, 6, 14),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      final labels = timeline!.items.map((item) => item.label).toList();
      expect(labels.first, ArchiveChangeTimelineCopy.firstSeenLabel);
      expect(labels[1], ArchiveChangeTimelineCopy.repeatedLabel);
      expect(labels, contains(ArchiveChangeTimelineCopy.lookedSofterLabel));
      expect(labels.last, ArchiveChangeTimelineCopy.stillWatchingLabel);
      for (var i = 1; i < labels.length; i++) {
        final currentIndex = ArchiveChangeTimeline.expectedLabelOrder
            .indexOf(labels[i]);
        final priorIndex =
            ArchiveChangeTimeline.expectedLabelOrder.indexOf(labels[i - 1]);
        expect(currentIndex, greaterThan(priorIndex));
      }
    });

    test('first seen and repeated appear after first proof', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      expect(
        timeline!.items.map((item) => item.kind).take(2).toList(),
        [
          ArchiveChangeTimelineItemKind.firstSeen,
          ArchiveChangeTimelineItemKind.repeated,
        ],
      );
      expect(
        timeline.items.first.body,
        ArchiveChangeTimelineCopy.firstSeenBody,
      );
      expect(
        timeline.items[1].body,
        ArchiveChangeTimelineCopy.repeatedBody,
      );
    });

    test('softer item appears when return-check evidence exists', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      final softer = timeline!.items.firstWhere(
        (item) => item.kind == ArchiveChangeTimelineItemKind.lookedSofter,
      );
      expect(softer.label, ArchiveChangeTimelineCopy.lookedSofterLabel);
      expect(softer.body, ArchiveChangeTimelineCopy.lookedSofterBody);
    });

    test('stronger item appears when return-check evidence exists', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.stronger,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      final stronger = timeline!.items.firstWhere(
        (item) => item.kind == ArchiveChangeTimelineItemKind.lookedStronger,
      );
      expect(stronger.label, ArchiveChangeTimelineCopy.lookedStrongerLabel);
      expect(stronger.body, ArchiveChangeTimelineCopy.lookedStrongerBody);
    });

    test('same item appears when return-check evidence exists', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.same,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      final same = timeline!.items.firstWhere(
        (item) => item.kind == ArchiveChangeTimelineItemKind.aboutTheSame,
      );
      expect(same.label, ArchiveChangeTimelineCopy.aboutTheSameLabel);
      expect(same.body, ArchiveChangeTimelineCopy.aboutTheSameBody);
    });

    test('changed item appears when PatternChanged evidence exists', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      final changed = timeline!.items.where(
        (item) => item.kind == ArchiveChangeTimelineItemKind.changedThisTime,
      );
      if (changed.isNotEmpty) {
        expect(changed.first.label, ArchiveChangeTimelineCopy.changedThisTimeLabel);
        expect(changed.first.body, ArchiveChangeTimelineCopy.changedThisTimeBody);
        expect(changed.first.body, isNot(PatternChangedCopy.bodyFallback));
      }
    });

    test('helpful item appears when HelpfulActionAppeared evidence exists', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.same,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      final helpful = timeline!.items.firstWhere(
        (item) => item.kind == ArchiveChangeTimelineItemKind.helpfulActionAppeared,
      );
      expect(helpful.label, ArchiveChangeTimelineCopy.helpfulActionAppearedLabel);
      expect(helpful.body, ArchiveChangeTimelineCopy.helpfulActionAppearedBody);
      expect(helpful.body, isNot(HelpfulActionAppearedCopy.bodyFallback));
    });

    test('watching item appears when archive is still tracking', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      expect(
        timeline!.items.last.kind,
        ArchiveChangeTimelineItemKind.stillWatching,
      );
      expect(
        timeline.items.last.body,
        ArchiveChangeTimelineCopy.stillWatchingBody,
      );
    });

    test('phrases are grounded and max 6 words', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fourWithHelpfulAction(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      for (final item in timeline!.items) {
        if (!item.hasPhrase) continue;
        final words = item.phrase!.trim().split(RegExp(r'\s+'));
        expect(words.length, lessThanOrEqualTo(6));
        expect(item.phrase!.length, lessThan(120));
      }
    });

    test('no transcript dumps in visible copy', () {
      final longTranscript = List.filled(40, 'word').join(' ');
      final entries = [
        _entry(id: 'e1', transcript: longTranscript),
        _entry(id: 'e2', transcript: longTranscript),
        _entry(id: 'e3', transcript: longTranscript),
      ];
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNull);
    });

    test('returns null before confirmed repeat foundation', () {
      final entries = [
        _entry(id: 'e1', transcript: 'One unrelated moment.'),
        _entry(id: 'e2', transcript: 'Another unrelated moment.'),
      ];
      expect(
        ArchiveChangeTimelineEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });
  });

  group('ArchiveChangeTimelineGates', () {
    test('does not show too early', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(
        ArchiveChangeTimelineGates.shouldShow(
          loaded: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          timeline: timeline,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveChangeTimelineCard', () {
    testWidgets('renders title subtitle and chain', (tester) async {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveChangeTimelineCard(
              timeline: timeline!,
              entryCount: 3,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('archive_change_timeline_card')), findsOneWidget);
      expect(find.text(ArchiveChangeTimelineCopy.title), findsOneWidget);
      expect(find.text(ArchiveChangeTimelineCopy.subtitle), findsOneWidget);
      expect(find.byKey(const Key('archive_change_timeline_chain')), findsOneWidget);
      expect(
        find.text(ArchiveChangeTimelineCopy.stillWatchingLabel),
        findsOneWidget,
      );
    });
  });

  group('Copy differentiation', () {
    test('does not duplicate other proof card titles or bodies', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(timeline, isNotNull);
      final joined = timeline!.visibleCopyBlocks.join('\n');

      expect(joined, isNot(contains(WhatChangedSinceLastTimeCopy.title)));
      expect(joined, isNot(contains(PatternChangedCopy.title)));
      expect(joined, isNot(contains(PatternChangedCopy.bodyFallback)));
      expect(
        ArchiveChangeTimelineCopy.helpfulActionAppearedLabel,
        isNot(HelpfulActionAppearedCopy.title),
      );
      expect(joined, isNot(contains(HelpfulActionAppearedCopy.bodyFallback)));
      expect(
        joined,
        isNot(contains(HelpfulActionAppearedCopy.bodyWithPhrase('walked outside'))),
      );
      expect(joined, isNot(contains(ArchiveBeliefSurfaceCopy.headline)));
    });

    test('no advice coaching therapy or personality language', () {
      for (final line in [
        ArchiveChangeTimelineCopy.title,
        ArchiveChangeTimelineCopy.subtitle,
        ArchiveChangeTimelineCopy.firstSeenBody,
        ArchiveChangeTimelineCopy.repeatedBody,
        ArchiveChangeTimelineCopy.lookedSofterBody,
        ArchiveChangeTimelineCopy.lookedStrongerBody,
        ArchiveChangeTimelineCopy.aboutTheSameBody,
        ArchiveChangeTimelineCopy.changedThisTimeBody,
        ArchiveChangeTimelineCopy.helpfulActionAppearedBody,
        ArchiveChangeTimelineCopy.stillWatchingBody,
      ]) {
        for (final violation in ProofSurfaceAdviceGuard.violationsIn(line)) {
          fail('"$line" contains banned phrase "$violation"');
        }
      }
    });

    test('patterns stack includes timeline after helpful action slot', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        helpfulActionAppearedVisible: true,
        archiveChangeTimelineVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        changeTimeline: timeline,
      );
      expect(blocks, contains(ArchiveChangeTimelineCopy.title));
      expect(blocks, contains(ArchiveChangeTimelineCopy.stillWatchingBody));
    });
  });

  group('Pro boundary copy', () {
    test('full archive history mentions evidence timeline', () {
      expect(
        ArchiveBeliefThreadCopy.fullArchiveHistoryBullets,
        contains('Full evidence timeline over time'),
      );
      final joined = [
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        ...ArchiveBeliefThreadCopy.fullArchiveHistoryBullets,
      ].join(' ').toLowerCase();
      expect(joined, contains('timeline'));
      expect(joined, contains('evidence'));
    });
  });
}
