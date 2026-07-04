import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_tracker.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_copy.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_engine.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_model.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_store.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_tracker.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/first25/first25_user_metrics.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_analytics.dart';
import 'package:voicememory_mobile/features/transcript_correction/transcript_correction_analytics.dart';
import 'package:voicememory_mobile/screens/testing_archiveme_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';

const _sampleTranscript =
    'I felt pressure at work before saying yes again even when I was tired today.';
const _samplePatternName = 'Saying yes when already tired';

void main() {
  setUp(() async {
    BetaActivationSummaryTracker.resetSessionForTest();
    BetaActivationLoopTracker.resetSessionForTest();
    EarlyArchiveProofAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    ReturnDayFlowAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/beta_activation_summary/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/beta_activation_summary/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await BetaActivationSummaryTracker.clearExtension();
    await BetaActivationLoopTracker.clearCounts();
  });

  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/beta_activation_summary/${DateTime.now().microsecondsSinceEpoch}_tear.json',
    );
  });

  group('BetaActivationSummaryEngine', () {
    test('resolveStatus walks activation ladder in priority order', () {
      const emptyLoop = BetaActivationLoopCounts();
      const emptyExt = BetaActivationSummaryExtension.empty;

      expect(
        BetaActivationSummaryEngine.resolveStatus(
          loop: emptyLoop,
          extension: emptyExt,
        ),
        BetaActivationStatus.notStarted,
      );

      expect(
        BetaActivationSummaryEngine.resolveStatus(
          loop: const BetaActivationLoopCounts(firstMomentSaved: 1),
          extension: emptyExt,
        ),
        BetaActivationStatus.firstMomentSaved,
      );

      expect(
        BetaActivationSummaryEngine.resolveStatus(
          loop: const BetaActivationLoopCounts(
            firstMomentSaved: 1,
            secondMomentSaved: 1,
          ),
          extension: emptyExt,
        ),
        BetaActivationStatus.almostAtFirstProof,
      );

      expect(
        BetaActivationSummaryEngine.resolveStatus(
          loop: const BetaActivationLoopCounts(secondMomentSaved: 1),
          extension: const BetaActivationSummaryExtension(
            firstProofReached: 1,
          ),
        ),
        BetaActivationStatus.firstProofReached,
      );

      expect(
        BetaActivationSummaryEngine.resolveStatus(
          loop: const BetaActivationLoopCounts(returnedAfterFirstProof: 1),
          extension: const BetaActivationSummaryExtension(firstProofReached: 1),
        ),
        BetaActivationStatus.returnedAfterProof,
      );

      expect(
        BetaActivationSummaryEngine.resolveStatus(
          loop: emptyLoop,
          extension: const BetaActivationSummaryExtension(
            returnDayFlowAnswered: 1,
          ),
        ),
        BetaActivationStatus.returnedAfterProof,
      );

      expect(
        BetaActivationSummaryEngine.resolveStatus(
          loop: const BetaActivationLoopCounts(returnedAfterFirstProof: 1),
          extension: const BetaActivationSummaryExtension(
            firstProofReached: 1,
            weeklyReviewOpened: 1,
          ),
        ),
        BetaActivationStatus.weeklyReviewReached,
      );
    });

    test('build merges loop and extension counters', () {
      final summary = BetaActivationSummaryEngine.build(
        loop: const BetaActivationLoopCounts(
          appOpened: 4,
          recordScreenSeen: 3,
          firstMomentSaved: 1,
          secondMomentSaved: 1,
          paywallSeen: 2,
          restoreTapped: 1,
        ),
        extension: const BetaActivationSummaryExtension(
          firstProofReached: 1,
          patternsOpened: 2,
          patternDetailsOpened: 1,
          weeklyReviewOpened: 1,
          returnDayFlowAnswered: 1,
          transcriptCorrected: 1,
          betaFeedbackOpened: 1,
          betaFeedbackSubmitted: 1,
        ),
      );

      expect(summary.appOpens, 4);
      expect(summary.recordScreenViews, 3);
      expect(summary.firstMomentSaved, 1);
      expect(summary.secondMomentSaved, 1);
      expect(summary.firstProofReached, 1);
      expect(summary.patternsOpened, 2);
      expect(summary.patternDetailsOpened, 1);
      expect(summary.weeklyReviewOpened, 1);
      expect(summary.returnDayFlowAnswered, 1);
      expect(summary.transcriptCorrected, 1);
      expect(summary.betaFeedbackOpened, 1);
      expect(summary.betaFeedbackSubmitted, 1);
      expect(summary.proScreenOpened, 2);
      expect(summary.restorePurchasesTapped, 1);
      expect(summary.status, BetaActivationStatus.weeklyReviewReached);
    });

    test('buildCopyText is metadata only', () {
      final summary = BetaActivationSummaryEngine.build(
        loop: const BetaActivationLoopCounts(
          appOpened: 2,
          firstMomentSaved: 1,
        ),
        extension: const BetaActivationSummaryExtension(
          firstProofReached: 1,
        ),
      );

      final copy = BetaActivationSummaryEngine.buildCopyText(summary);

      expect(copy, contains('ArchiveMe beta progress summary'));
      expect(copy, contains('Activation status'));
      expect(copy, contains('First proof reached'));
      expect(copy, contains('App opens: 2'));
      expect(copy.toLowerCase(), isNot(contains(_sampleTranscript.toLowerCase())));
      expect(copy.toLowerCase(), isNot(contains(_samplePatternName.toLowerCase())));
      expect(copy.toLowerCase(), isNot(contains('transcript:')));
      expect(copy.toLowerCase(), isNot(contains('feedback note')));
      expect(copy.toLowerCase(), isNot(contains('pattern name')));
    });
  });

  group('BetaActivationSummaryTracker', () {
    test('funnel events increment extension counters', () async {
      EarlyArchiveProofAnalytics.firstProofMomentSeen(
        entryCount: 2,
        phraseCount: 1,
        hasStrongEvidence: true,
      );
      TranscriptCorrectionAnalytics.saved(
        source: 'record',
        entryCount: 2,
        hasParentEntry: false,
      );
      ReturnDayFlowAnalytics.answered(
        source: 'record',
        entryCount: 2,
        answer: 'same',
        hasGroundedPhrase: true,
      );
      ActivationFunnelAnalytics.track('beta_feedback_opened', source: 'account');
      ActivationFunnelAnalytics.track(
        'beta_feedback_submitted',
        source: 'account',
        optionType: 'clear',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final extension = await BetaActivationSummaryTracker.loadExtension();
      expect(extension.firstProofReached, 1);
      expect(extension.transcriptCorrected, 1);
      expect(extension.returnDayFlowAnswered, 1);
      expect(extension.betaFeedbackOpened, 1);
      expect(extension.betaFeedbackSubmitted, 1);
    });

    test('patterns opened session dedupes', () async {
      await First25UserMetrics.trackArchiveOpened(surface: 'archive_beliefs');
      await First25UserMetrics.trackArchiveOpened(surface: 'archive_beliefs');
      await Future<void>.delayed(Duration.zero);

      final extension = await BetaActivationSummaryTracker.loadExtension();
      expect(extension.patternsOpened, 1);
    });

    test('loadAll and build show persisted local counts', () async {
      await BetaActivationLoopTracker.trackAppOpened();
      await BetaActivationLoopTracker.trackRecordScreenSeen();
      await BetaActivationLoopTracker.trackFirstMomentSaved();
      await BetaActivationSummaryTracker.trackPatternsOpened();

      final loaded = await BetaActivationSummaryTracker.loadAll();
      final summary = BetaActivationSummaryEngine.build(
        loop: loaded.loop,
        extension: loaded.extension,
      );

      expect(summary.appOpens, 1);
      expect(summary.recordScreenViews, 1);
      expect(summary.firstMomentSaved, 1);
      expect(summary.patternsOpened, 1);
      expect(summary.status, BetaActivationStatus.firstMomentSaved);
    });
  });

  group('Testing ArchiveMe scope', () {
    test('beta progress summary lives in Testing ArchiveMe screen only', () {
      final testingSource =
          File('lib/screens/testing_archiveme_screen.dart').readAsStringSync();
      final accountSource =
          File('lib/screens/account_screen.dart').readAsStringSync();
      final settingsSource =
          File('lib/screens/settings_screen.dart').readAsStringSync();

      expect(
        testingSource.contains('testing_archiveme_beta_progress_summary'),
        isTrue,
      );
      expect(testingSource.contains('BetaActivationSummarySheet'), isTrue);
      expect(accountSource.contains('BetaActivationSummarySheet'), isFalse);
      expect(settingsSource.contains('BetaActivationSummarySheet'), isFalse);
      expect(settingsSource.contains('ArchiveBetaMissionGate.isEnabled'), isTrue);
    });

    testWidgets('Testing ArchiveMe shows beta progress summary when enabled', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = true;

      await tester.pumpWidget(const MaterialApp(home: TestingArchiveMeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('testing_archiveme_beta_progress_summary')),
        findsOneWidget,
      );
      expect(find.text(BetaActivationSummaryCopy.openLink), findsOneWidget);
    });

    testWidgets('Testing ArchiveMe hides mission content when beta flag off', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = false;

      await tester.pumpWidget(const MaterialApp(home: TestingArchiveMeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('testing_archiveme_beta_progress_summary')),
        findsNothing,
      );
    });
  });

  group('Privacy and protected areas', () {
    test('copy strings avoid collecting user content fields', () {
      for (final line in BetaActivationSummaryCopy.allVisibleCopy()) {
        expect(line.toLowerCase(), isNot(contains('audio')));
        expect(line.toLowerCase(), isNot(contains('feedback note')));
        expect(line.toLowerCase(), isNot(contains('pattern name')));
      }
      expect(
        BetaActivationSummaryCopy.transcriptCorrected,
        'Transcript corrected',
      );
    });

    test('feature files do not touch billing or signing surfaces', () {
      final featureDir = Directory(
        'lib/features/beta_activation',
      );
      final widgetFile = File('lib/widgets/account/beta_activation_summary_sheet.dart');
      final sources = [
        ...featureDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
        widgetFile,
      ];

      const banned = [
        'RevenueCat',
        'Purchases.',
        'entitlement',
        'product_id',
        'CFBundleVersion',
        'ipa',
        'signing',
        'api.archive',
      ];

      for (final file in sources) {
        final text = file.readAsStringSync();
        for (final token in banned) {
          expect(
            text.contains(token),
            isFalse,
            reason: '${file.path} must not reference $token',
          );
        }
      }
    });

    test('store key is local prefs only', () {
      expect(
        BetaActivationSummaryStore.countsKey,
        'beta_activation_summary_counts_v1',
      );
    });
  });
}
