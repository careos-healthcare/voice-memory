import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/open_capture/open_capture_analytics.dart';
import 'package:voicememory_mobile/features/open_capture/open_capture_copy.dart';
import 'package:voicememory_mobile/features/open_capture/open_capture_engine.dart';
import 'package:voicememory_mobile/features/open_capture/open_capture_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/widgets/record/open_capture_prompt_chips.dart';

import 'support/record_screen_layout_assertions.dart';

JournalEntry _entry({required String id, required String transcript}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  String? tappedPrompt;

  setUp(() {
    OpenCaptureAnalytics.resetForTest();
    OpenCaptureAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    tappedPrompt = null;
  });

  tearDown(OpenCaptureAnalytics.resetForTest);

  group('OpenCaptureEngine visibility', () {
    test('zero-entry user sees open capture chips', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isTrue,
      );
    });

    test('early user sees open capture chips', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 7,
        ),
        isTrue,
      );
    });

    test('users over 7 entries do not see chips', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 8,
        ),
        isFalse,
      );
    });

    test('hidden while recording', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: true,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 2,
        ),
        isFalse,
      );
    });

    test('hidden post-save', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: true,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 2,
        ),
        isFalse,
      );
    });

    test('hidden during degraded transcript', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: true,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 2,
        ),
        isFalse,
      );
    });

    test('hidden during first proof payoff', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 3,
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 3,
        ),
        isFalse,
      );
    });

    test('hidden on permission blocked screen', () {
      expect(
        OpenCaptureEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: true,
          entryCount: 0,
        ),
        isFalse,
      );
    });
  });

  group('OpenCapturePromptChips', () {
    Future<void> pumpChips(
      WidgetTester tester, {
      bool usePromptPrefill = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: OpenCapturePromptChips.test(
                    source: 'test',
                    entryCount: 2,
                    usePromptPrefill: usePromptPrefill,
                    onChipTap: (chip) => tappedPrompt = chip.promptStarter,
                  ),
                ),
              ),
              GoRoute(
                path: '/away',
                builder: (context, state) => const Scaffold(body: Text('Away')),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders "Save anything you notice."', (tester) async {
      await pumpChips(tester);

      expect(find.text(OpenCaptureCopy.header), findsOneWidget);
    });

    testWidgets('renders "It does not have to be a pattern yet."', (
      tester,
    ) async {
      await pumpChips(tester);

      expect(find.text(OpenCaptureCopy.subline), findsOneWidget);
    });

    testWidgets('all chips render', (tester) async {
      await pumpChips(tester);

      for (final chip in OpenCaptureChip.all) {
        expect(find.text(chip.label), findsOneWidget);
      }
    });

    testWidgets(
      'tapping chip shows "Start anywhere. ArchiveMe looks for the pattern later."',
      (tester) async {
        await pumpChips(tester);

        await tester.tap(find.text(OpenCaptureCopy.thoughtLabel));
        await tester.pump();

        expect(find.text(OpenCaptureCopy.chipSelectedCopy), findsOneWidget);
      },
    );

    testWidgets('tapping chip prefills prompt starter without routing away', (
      tester,
    ) async {
      await pumpChips(tester);

      await tester.tap(find.text(OpenCaptureCopy.decisionLabel));
      await tester.pump();

      expect(tappedPrompt, OpenCaptureCopy.decisionPrompt);
      expect(find.text('Away'), findsNothing);
    });

    testWidgets('without prompt prefill shows fallback helper', (tester) async {
      await pumpChips(tester, usePromptPrefill: false);

      await tester.tap(find.text(OpenCaptureCopy.worryLabel));
      await tester.pump();

      expect(find.text(OpenCaptureCopy.fallbackHelper), findsOneWidget);
      expect(find.text(OpenCaptureCopy.chipSelectedCopy), findsNothing);
    });

    testWidgets('tapping chip does not change evidence classification', (
      tester,
    ) async {
      final entry = _entry(
        id: 'e1',
        transcript: 'A quiet lunch with a friend today.',
      );
      final before = ArchiveEvidenceQuality.assess(entry);

      await pumpChips(tester);
      await tester.tap(find.text(OpenCaptureCopy.pressureLabel));
      await tester.pump();

      final after = ArchiveEvidenceQuality.assess(entry);
      expect(after.allowsInsights, before.allowsInsights);
      expect(after.level, before.level);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpChips(tester);

      await tester.tap(find.text(OpenCaptureCopy.winLabel));
      await tester.pump();

      expect(analyticsEvents, hasLength(2));
      expect(analyticsEvents[0].event, OpenCaptureAnalytics.seenEvent);
      expect(analyticsEvents[1].event, OpenCaptureAnalytics.chipTappedEvent);
      expect(
        analyticsEvents[1].props.keys,
        containsAll(['source', 'entry_count', 'chip_type']),
      );
      expect(analyticsEvents[1].props['chip_type'], 'win');
      for (final record in analyticsEvents) {
        for (final value in record.props.values) {
          final text = value.toString().toLowerCase();
          expect(text, isNot(contains('transcript')));
        }
      }
    });

    testWidgets('no therapy/medical copy', (tester) async {
      await pumpChips(tester);

      final blob = OpenCaptureCopy.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
    });
  });

  group('Open capture placement', () {
    test(
      'chips sit under RecordCaptureModesCard on record screen when not simplified',
      () {
        expectRecordScreenLayoutBefore(
          earlier: 'RecordCaptureModesCard(',
          later: 'showOpenCapturePromptChips',
        );
        expect(readRecordScreenSource(), contains('!firstUseSimplifiedRecord'));
      },
    );

    test('chip tap sets selected prompt line only', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final chipsIndex = source.indexOf('OpenCapturePromptChips(');
      final snippet = source.substring(chipsIndex, chipsIndex + 400);
      expect(
        snippet,
        matches(RegExp(r'_selectedPromptLine\s*=\s*chip\.promptStarter')),
      );
      expect(snippet, isNot(contains('navigateToCaptureMode')));
      expect(snippet, isNot(contains('context.push')));
    });
  });

  group('Open capture copy guard', () {
    test('copy avoids percentages and fake evidence', () {
      for (final line in OpenCaptureCopy.allVisibleStrings()) {
        expect(line, isNot(contains('%')));
        expect(line.toLowerCase(), isNot(contains('fake')));
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('engine does not touch evidence gates', () {
      final content = File(
        'lib/features/open_capture/open_capture_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(content, isNot(contains('archiveevidencequalitygate')));
      expect(content, isNot(contains('allowsbeliefsurfaces')));
    });

    test('feature files avoid billing surfaces', () {
      const paths = [
        'lib/features/open_capture/open_capture_copy.dart',
        'lib/features/open_capture/open_capture_model.dart',
        'lib/features/open_capture/open_capture_engine.dart',
        'lib/features/open_capture/open_capture_analytics.dart',
        'lib/widgets/record/open_capture_prompt_chips.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
      }
    });

    test('prompt starters stay generic and do not force categories', () {
      for (final chip in OpenCaptureChip.all) {
        expect(
          ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback([
            _entry(id: chip.type.name, transcript: chip.promptStarter),
          ]),
          isFalse,
        );
      }
    });
  });
}
