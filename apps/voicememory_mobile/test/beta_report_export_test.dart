import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:voicememory_mobile/features/beta/beta_metrics_decision_copy.dart';
import 'package:voicememory_mobile/features/beta/beta_report_export_copy.dart';
import 'package:voicememory_mobile/features/beta/beta_report_export_engine.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_copy.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_model.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_store.dart';
import 'package:voicememory_mobile/features/beta/proof_of_value_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/debug/beta_report_export_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/beta_report_export/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

BetaActivationLoopCounts _loopCounts({
  int appOpened = 10,
  int firstMomentSaved = 8,
  int secondMomentSaved = 6,
  int thirdMomentSaved = 4,
  int returnCheckAnswered = 3,
  int purchaseTapped = 1,
}) => BetaActivationLoopCounts(
  appOpened: appOpened,
  firstMomentSaved: firstMomentSaved,
  secondMomentSaved: secondMomentSaved,
  thirdMomentSaved: thirdMomentSaved,
  returnCheckAnswered: returnCheckAnswered,
  purchaseTapped: purchaseTapped,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = false;
    await CoreValueFeedbackStore.resetForTest();
  });

  group('BetaReportExportEngine', () {
    late Directory tempDir;
    test('copied report includes tester loop counts', () {
      final report = BetaReportExportEngine.build(betaCounts: _loopCounts());
      final text = report.formattedText;
      expect(text, contains('- App opened: 10'));
      expect(text, contains('- First moment saved: 8'));
      expect(text, contains('- Second moment saved: 6'));
      expect(text, contains('- First proof reached: 4'));
      expect(text, contains('- Return check answered: 3'));
      expect(text, contains('- Pro tapped: 1'));
    });

    test('copied report includes core value local answer', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_beta_report_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      final store = CoreValueFeedbackStore(_MemoryPrefs());
      await store.saveAnswer(
        answer: CoreValueFeedbackAnswer.notYet,
        entryCount: 3,
        source: CoreValueFeedbackSource.patternsArchive,
      );

      final text = BetaReportExportEngine.build(
        betaCounts: _loopCounts(),
      ).formattedText;
      expect(
        text,
        contains('- Local answer: ${CoreValueFeedbackCopy.answerNotYet}'),
      );
    });

    test(
      'copied report includes proof of value summary and recommendation',
      () {
        final report = BetaReportExportEngine.build(
          betaCounts: _loopCounts(firstMomentSaved: 6, secondMomentSaved: 4),
        );
        final text = report.formattedText;
        expect(text, contains('Proof of value:'));
        expect(text, contains('- Summary: ${report.proofOfValueSummary}'));
        expect(
          text,
          contains('- Recommendation: ${report.proofOfValueRecommendation}'),
        );
        expect(
          report.proofOfValueRecommendation,
          ProofOfValueCopy.recommendationFixFirstUse,
        );
      },
    );

    test('copied report includes manual questions', () {
      final text = BetaReportExportEngine.build(
        betaCounts: _loopCounts(),
      ).formattedText;
      expect(text, contains('Manual questions:'));
      for (var i = 0; i < BetaReportExportCopy.manualQuestions.length; i++) {
        expect(
          text,
          contains('${i + 1}. ${BetaReportExportCopy.manualQuestions[i]}'),
        );
      }
    });

    test('copied report includes decision bottleneck and fix area', () {
      final report = BetaReportExportEngine.build(
        betaCounts: _loopCounts(firstMomentSaved: 6),
      );
      final text = report.formattedText;
      expect(text, contains('Decision:'));
      expect(text, contains('- Bottleneck: ${report.decisionBottleneck}'));
      expect(text, contains('- Fix area: ${report.decisionFixArea}'));
      expect(
        report.decisionBottleneck,
        BetaMetricsDecisionCopy.summaryFirstScreen,
      );
    });

    test('report format matches spec header and sections', () {
      final text = BetaReportExportEngine.build(
        betaCounts: _loopCounts(),
      ).formattedText;
      expect(text.startsWith('ArchiveMe Beta Report\n'), isTrue);
      expect(text, contains('\n\nTester loop:\n'));
      expect(text, contains('\n\nCore value:\n'));
      expect(text, contains('\n\nProof of value:\n'));
      expect(text, contains('\n\nDecision:\n'));
      expect(text, contains('\n\nManual questions:\n'));
    });

    test('report excludes transcript phrase and user content', () {
      final text = BetaReportExportEngine.build(
        betaCounts: _loopCounts(),
      ).formattedText.toLowerCase();
      expect(text, isNot(contains('transcript')));
      expect(text, isNot(contains('said yes again')));
      expect(text, isNot(contains('journal entry')));
      expect(text, isNot(contains('phrase text')));
    });

    test('report excludes secrets and API keys', () {
      final text = BetaReportExportEngine.build(
        betaCounts: _loopCounts(),
      ).formattedText;
      expect(text, isNot(contains('REVENUECAT_')));
      expect(text, isNot(contains('http://')));
      expect(text, isNot(contains('https://')));
      expect(text, isNot(contains('sk_')));
      expect(text, isNot(contains('api_key')));
    });

    test('no answer yet when core value feedback empty', () {
      final text = BetaReportExportEngine.build(
        betaCounts: _loopCounts(),
      ).formattedText;
      expect(
        text,
        contains(
          '- Local answer: ${CoreValueFeedbackCopy.diagnosticsNoAnswer}',
        ),
      );
    });
  });

  group('BetaReportExportCard', () {
    testWidgets('hidden when developer diagnostics locked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaReportExportCard(
              report: BetaReportExportEngine.build(betaCounts: _loopCounts()),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('beta_report_export_hidden')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('beta_report_export_copy_button')),
        findsNothing,
      );
    });

    testWidgets('visible when unlocked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaReportExportCard(
              report: BetaReportExportEngine.build(betaCounts: _loopCounts()),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('beta_report_export_copy_button')),
        findsOneWidget,
      );
      expect(find.text(BetaReportExportCopy.copyButtonLabel), findsOneWidget);
    });

    testWidgets('copy shows confirmation', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      var copiedText = '';
      final report = BetaReportExportEngine.build(betaCounts: _loopCounts());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaReportExportCard.test(
              report: report,
              copyText: (text) async {
                copiedText = text;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('beta_report_export_copy_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(copiedText, report.formattedText);
      expect(
        find.text(BetaReportExportCopy.copiedConfirmation),
        findsOneWidget,
      );
    });
  });
}
