import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_analytics.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_engine.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_gates.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/patterns/belief_change_moment_card.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:archiveme_mobile/widgets/weekly_review/weekly_archive_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: localAudioPath ?? '/tmp/$id.m4a',
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
        'The meeting invite came in and I said yes again with no capacity left for it.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fourWithDifferentLatestPhrase() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I checked my calendar before answering when they asked me to take on more work.',
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

List<JournalEntry> _fiveWithLowerUrgency() => [
  ..._fourRelatedRepeatEntries(),
  _entry(
    id: 'e5',
    transcript:
        'Same yes pattern came back but it felt less urgent and easier to stop.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
];

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
  int entryCountAtCapture = 4,
}) => RepeatReturnCheckRecord(
  entryId: entryId,
  choice: choice,
  entryCountAtCapture: entryCountAtCapture,
  createdAt: DateTime(2026, 6, 13),
);

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    BeliefChangeMomentAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    await WhatChangedV2Store.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  group('BeliefChangeMomentEngine', () {
    test('hidden with no repeated pattern foundation', () {
      expect(
        BeliefChangeMomentEngine.build(
          entries: [
            _entry(id: 'a', transcript: 'A quiet lunch with a friend today.'),
            _entry(
              id: 'b',
              transcript: 'Another unrelated note about errands.',
            ),
          ],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('hidden with repeated pattern but no change evidence', () {
      expect(
        BeliefChangeMomentEngine.build(
          entries: _fourRelatedRepeatEntries(),
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('hidden for generic test entries', () {
      final entries = [
        _entry(id: 'g1', transcript: 'This is a test to check function'),
        _entry(id: 'g2', transcript: 'This is a second test for pressure'),
        _entry(id: 'g3', transcript: 'This is a third test for pressure'),
        _entry(id: 'g4', transcript: 'This is a fourth test for pressure'),
      ];
      expect(
        BeliefChangeMomentEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('hidden for pending placeholder transcript', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'p4',
          transcript: _placeholder,
          localAudioPath: '/tmp/p4.m4a',
        ),
      ];
      expect(
        BeliefChangeMomentEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('shows when later evidence is softer', () {
      final moment = BeliefChangeMomentEngine.build(
        entries: _fiveWithLowerUrgency(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e5',
            choice: RepeatReturnCheckChoice.softer,
            entryCountAtCapture: 5,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(moment, isNotNull);
      expect(moment!.changeType, BeliefChangeType.lowerUrgency);
      expect(BeliefChangeMomentCopy.title, contains('may be changing'));
      expect(moment.earlierSnippet.quote, isNotEmpty);
      expect(moment.laterSnippet.quote, isNotEmpty);
    });

    test('shows when later evidence has different response', () {
      final moment = BeliefChangeMomentEngine.build(
        entries: _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(moment, isNotNull);
      expect(moment!.changeType, BeliefChangeType.differentResponse);
    });

    test('shows when helpful action appears', () {
      final moment = BeliefChangeMomentEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(moment, isNotNull);
      expect(moment!.changeType, BeliefChangeType.helpfulAction);
    });

    test('copy avoids advice and diagnosis language', () {
      for (final line in BeliefChangeMomentCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
      final joined = BeliefChangeMomentCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('you always')));
      expect(joined, isNot(contains('has changed')));
    });
  });

  group('BeliefChangeMomentGates', () {
    test('requires four entries and grounded moment', () {
      final moment = BeliefChangeMomentEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(
        BeliefChangeMomentGates.shouldShow(
          loaded: true,
          entryCount: 4,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          moment: moment,
        ),
        isTrue,
      );
      expect(
        BeliefChangeMomentGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          moment: moment,
        ),
        isFalse,
      );
    });
  });

  group('BeliefChangeMomentCard', () {
    testWidgets('View change timeline opens existing timeline sheet', (
      tester,
    ) async {
      final moment = BeliefChangeMomentEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(moment?.canViewChangeTimeline, isTrue);

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefChangeMomentCard(
                moment: moment!,
                entryCount: 4,
                source: 'patterns',
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('belief_change_moment_timeline_cta')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('archive_change_timeline_card')),
        findsOneWidget,
      );
    });
  });

  group('BeliefChangeMomentAnalytics', () {
    test('payload excludes transcript text', () {
      final captured = <({String event, Map<String, Object> props})>[];
      BeliefChangeMomentAnalytics.captureForTest = (event, properties) =>
          captured.add((event: event, props: properties));

      BeliefChangeMomentAnalytics.seen(
        source: 'patterns',
        entryCount: 4,
        changeType: BeliefChangeType.helpfulAction,
      );

      expect(captured.length, 1);
      expect(captured.first.event, BeliefChangeMomentAnalytics.seenEvent);
      expect(captured.first.props.keys.toSet(), {
        'source',
        'entry_count',
        'change_type',
      });
      expect(captured.first.props['change_type'], 'helpful_action');
      final values = captured.first.props.values
          .map((v) => v.toString().toLowerCase())
          .join(' ');
      expect(values, isNot(contains('paused before')));
      expect(values, isNot(contains('said yes')));
    });
  });

  group('Surface integration', () {
    testWidgets(
      'pattern detail shows belief change moment after why this matters',
      (tester) async {
        final entries = _fourWithHelpfulAction();
        final detail = PatternDetailEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(detail, isNotNull);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PatternDetailSheet(
                detail: detail!,
                buildInput: PatternDetailBuildInput(
                  entries: entries,
                  viewingConfirmedRepeatOrTimeline: true,
                  returnChecks: [
                    _answeredRecord(
                      entryId: 'e4',
                      choice: RepeatReturnCheckChoice.softer,
                    ),
                  ],
                ),
                entryCount: 4,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('pattern_detail_why_this_matters_heading')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('belief_change_moment_card')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'weekly review sheet shows belief change moment when available',
      (tester) async {
        final entries = _fourWithHelpfulAction();
        final review = weekly_review_surface.WeeklyArchiveReviewEngine.build(
          entries: entries,
        );
        expect(review, isNotNull);
        final moment = BeliefChangeMomentEngine.build(
          entries: entries,
          returnChecks: [
            _answeredRecord(
              entryId: 'e4',
              choice: RepeatReturnCheckChoice.softer,
            ),
          ],
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(moment, isNotNull);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WeeklyArchiveReviewSheet(
                review: review!,
                entryCount: 4,
                beliefChangeMoment: moment,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('weekly_archive_review_sheet')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('belief_change_moment_card')),
          findsOneWidget,
        );
      },
    );
  });

  group('Protected areas', () {
    test('feature files avoid billing and signing surfaces', () {
      const banned = ['RevenueCat', 'Purchases.', 'CFBundleVersion', 'signing'];
      final files = [
        'lib/features/belief_changes/belief_change_moment_copy.dart',
        'lib/features/belief_changes/belief_change_moment_engine.dart',
        'lib/features/belief_changes/belief_change_moment_analytics.dart',
        'lib/widgets/patterns/belief_change_moment_card.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(
            text.contains(token),
            isFalse,
            reason: '$path must not reference $token',
          );
        }
      }
    });
  });
}