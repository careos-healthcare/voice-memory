import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/features/beta/proof_of_value_copy.dart';
import 'package:voicememory_mobile/features/beta/proof_of_value_engine.dart';
import 'package:voicememory_mobile/features/beta/proof_of_value_model.dart';
import 'package:voicememory_mobile/features/beta/proof_value_bottleneck_playbook_copy.dart';
import 'package:voicememory_mobile/features/beta/proof_value_bottleneck_playbook_engine.dart';
import 'package:voicememory_mobile/features/beta/proof_value_bottleneck_playbook_model.dart';
import 'package:voicememory_mobile/widgets/debug/proof_value_bottleneck_playbook_card.dart';

ProofOfValueInput _input({
  int totalTesters = 10,
  int appOpened = 10,
  int firstMomentSaved = 0,
  int secondMomentSaved = 0,
  int firstProofReached = 0,
  int returnCheckAnswered = 0,
  int proTapped = 0,
  int? coreValueYes,
  int? coreValueGeneric,
  int? wouldKeepUsing,
  int? wouldPay,
}) =>
    ProofOfValueInput(
      totalTesters: totalTesters,
      appOpened: appOpened,
      firstMomentSaved: firstMomentSaved,
      secondMomentSaved: secondMomentSaved,
      firstProofReached: firstProofReached,
      returnCheckAnswered: returnCheckAnswered,
      proTapped: proTapped,
      coreValueYes: coreValueYes,
      coreValueGeneric: coreValueGeneric,
      wouldKeepUsing: wouldKeepUsing,
      wouldPay: wouldPay,
    );

ProofValueBottleneckPlaybookReport _playbookFor(ProofOfValueInput input) {
  final proofReport = ProofOfValueEngine.build(input: input);
  return ProofValueBottleneckPlaybookEngine.build(proofReport: proofReport);
}

void main() {
  tearDown(DeveloperSettingsGate.resetForTest);

  group('ProofValueBottleneckPlaybookEngine', () {
    test('reads Proof of Value recommendation', () {
      final proofReport = ProofOfValueEngine.build(
        input: _input(totalTesters: 3, appOpened: 3),
      );
      final playbook = ProofValueBottleneckPlaybookEngine.build(
        proofReport: proofReport,
      );

      expect(
        playbook.activeRecommendation,
        proofReport.recommendation,
      );
      expect(
        playbook.activeRecommendation,
        ProofOfValueCopy.recommendationRunMoreTesters,
      );
    });

    test('renders title and subtitle', () {
      final playbook = _playbookFor(_input(firstMomentSaved: 6));

      expect(playbook.title, ProofValueBottleneckPlaybookCopy.cardTitle);
      expect(playbook.subtitle, ProofValueBottleneckPlaybookCopy.cardSubtitle);
    });

    test('run more testers playbook content', () {
      final playbook = _playbookFor(_input(totalTesters: 3, appOpened: 3));
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.runMoreTesters);
      expect(entry.meaning, ProofValueBottleneckPlaybookCopy.runMoreTestersMeaning);
      expect(entry.fixArea, ProofValueBottleneckPlaybookCopy.runMoreTestersFixArea);
      expect(entry.inspectSurfaces, contains('Beta Report Export'));
      expect(entry.guardrail, contains('No product changes'));
      expect(
        entry.suggestedTestFiles,
        contains('release_candidate_smoke_test.dart'),
      );
      expect(entry.testCommand, contains('flutter test'));
    });

    test('fix first-use playbook content', () {
      final playbook = _playbookFor(_input(firstMomentSaved: 6));
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.fixFirstUse);
      expect(entry.meaning, ProofValueBottleneckPlaybookCopy.fixFirstUseMeaning);
      expect(entry.fixArea, ProofValueBottleneckPlaybookCopy.fixFirstUseFixArea);
      expect(entry.inspectSurfaces, contains('Record first-use capture'));
      expect(entry.guardrail, contains('Do not add new cards'));
      expect(
        entry.suggestedTestFiles,
        contains('record_screen_framing_copy_test.dart'),
      );
    });

    test('fix return loop playbook content', () {
      final playbook = _playbookFor(
        _input(firstMomentSaved: 8, secondMomentSaved: 4),
      );
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.fixReturnLoop);
      expect(entry.meaning, ProofValueBottleneckPlaybookCopy.fixReturnLoopMeaning);
      expect(entry.fixArea, ProofValueBottleneckPlaybookCopy.fixReturnLoopFixArea);
      expect(entry.inspectSurfaces, contains('PostSaveReturnHandoffCopy'));
      expect(entry.guardrail, contains('No notifications yet'));
      expect(entry.suggestedTestFiles, contains('tester_mission_test.dart'));
    });

    test('fix first proof playbook content', () {
      final playbook = _playbookFor(
        _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 2,
        ),
      );
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.fixFirstProof);
      expect(entry.meaning, ProofValueBottleneckPlaybookCopy.fixFirstProofMeaning);
      expect(entry.fixArea, ProofValueBottleneckPlaybookCopy.fixFirstProofFixArea);
      expect(entry.inspectSurfaces, contains('FirstProofMoment gates'));
      expect(entry.guardrail, contains('Do not lower proof quality'));
      expect(
        entry.suggestedTestFiles,
        contains('first_three_session_loop_test.dart'),
      );
    });

    test('fix evidence specificity playbook content', () {
      final playbook = _playbookFor(
        _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueGeneric: 3,
          coreValueYes: 1,
        ),
      );
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.fixEvidence);
      expect(entry.meaning, ProofValueBottleneckPlaybookCopy.fixEvidenceMeaning);
      expect(entry.fixArea, ProofValueBottleneckPlaybookCopy.fixEvidenceFixArea);
      expect(
        entry.inspectSurfaces,
        contains('ConfirmedRepeatEvidencePhraseEngine'),
      );
      expect(entry.guardrail, contains('possible-repeat fallback'));
      expect(
        entry.suggestedTestFiles,
        contains('archive_current_belief_test.dart'),
      );
    });

    test('strengthen retention playbook content', () {
      final playbook = _playbookFor(
        _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
          wouldKeepUsing: 1,
        ),
      );
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.strengthenRetention);
      expect(
        entry.meaning,
        ProofValueBottleneckPlaybookCopy.strengthenRetentionMeaning,
      );
      expect(
        entry.fixArea,
        ProofValueBottleneckPlaybookCopy.strengthenRetentionFixArea,
      );
      expect(entry.inspectSurfaces, contains('Evidence timeline'));
      expect(entry.guardrail, contains('Do not add new insight cards'));
      expect(
        entry.suggestedTestFiles,
        contains('weekly_archive_review_test.dart'),
      );
    });

    test('strengthen Pro playbook content and guardrail', () {
      final playbook = _playbookFor(
        _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
          wouldKeepUsing: 3,
          wouldPay: 0,
        ),
      );
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.strengthenPro);
      expect(entry.meaning, ProofValueBottleneckPlaybookCopy.strengthenProMeaning);
      expect(entry.fixArea, ProofValueBottleneckPlaybookCopy.strengthenProFixArea);
      expect(entry.inspectSurfaces, contains('Restore purchases visibility'));
      expect(entry.guardrail, contains('RevenueCat'));
      expect(entry.guardrail, contains('product IDs'));
      expect(entry.guardrail, contains('restore'));
      expect(
        entry.suggestedTestFiles,
        contains('paywall_timing_gates_test.dart'),
      );
    });

    test('widen beta playbook content', () {
      final playbook = _playbookFor(
        _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
          wouldKeepUsing: 3,
          wouldPay: 1,
        ),
      );
      final entry = playbook.entry;

      expect(entry.id, ProofValueBottleneckPlaybookId.widenBeta);
      expect(entry.meaning, ProofValueBottleneckPlaybookCopy.widenBetaMeaning);
      expect(entry.fixArea, ProofValueBottleneckPlaybookCopy.widenBetaFixArea);
      expect(entry.inspectSurfaces, contains('TestFlight smoke checklist'));
      expect(entry.guardrail, contains('No product changes'));
      expect(
        entry.suggestedTestFiles,
        contains('beta_report_export_test.dart'),
      );
    });

    test('no transcript phrase user content or secrets', () {
      final joined = _playbookFor(
        _input(
          firstMomentSaved: 8,
          secondMomentSaved: 6,
          firstProofReached: 4,
          coreValueYes: 3,
        ),
      ).visibleCopyBlocks.join('\n').toLowerCase();

      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('journal entry')));
      expect(joined, isNot(contains('phrase text')));
      expect(joined, isNot(contains('said yes again')));
      expect(joined, isNot(contains('revenuecat_')));
      expect(joined, isNot(contains('sk_')));
      expect(joined, isNot(contains('https://')));
    });
  });

  group('ProofValueBottleneckPlaybookCard', () {
    testWidgets('hidden when developer diagnostics locked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofValueBottleneckPlaybookCard(
              report: _playbookFor(_input()),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('proof_value_bottleneck_playbook_hidden')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('proof_value_bottleneck_playbook_card')),
        findsNothing,
      );
    });

    testWidgets('visible when unlocked and renders sections', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);

      final playbook = _playbookFor(_input(firstMomentSaved: 6));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofValueBottleneckPlaybookCard(report: playbook),
          ),
        ),
      );

      expect(
        find.byKey(const Key('proof_value_bottleneck_playbook_card')),
        findsOneWidget,
      );
      expect(
        find.text(ProofValueBottleneckPlaybookCopy.cardTitle),
        findsOneWidget,
      );
      expect(
        find.text(ProofValueBottleneckPlaybookCopy.cardSubtitle),
        findsOneWidget,
      );
      expect(find.textContaining(playbook.activeRecommendation), findsOneWidget);
      expect(
        find.text(ProofValueBottleneckPlaybookCopy.sectionMeaning),
        findsOneWidget,
      );
      expect(
        find.text(ProofValueBottleneckPlaybookCopy.sectionFixArea),
        findsOneWidget,
      );
      expect(
        find.text(ProofValueBottleneckPlaybookCopy.sectionInspect),
        findsOneWidget,
      );
      expect(
        find.text(ProofValueBottleneckPlaybookCopy.sectionGuardrail),
        findsOneWidget,
      );
      expect(
        find.text(ProofValueBottleneckPlaybookCopy.sectionSuggestedTests),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('proof_value_bottleneck_playbook_test_command')),
        findsOneWidget,
      );
    });
  });
}
