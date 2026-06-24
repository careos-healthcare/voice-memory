import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_response_copy.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_response_engine.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_response_models.dart';

const _playbookPath = 'docs/BETA_FEEDBACK_RESPONSE_PLAYBOOK.md';

const _privateSnippet = 'felt pressure at work before saying yes';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
  'archiveme knows',
  'product-market fit',
  'product market fit',
  'pmf proven',
  'pmf is proven',
  'burnout',
];

BetaFeedbackResponseInput _input({
  bool capacityWedgeActive = true,
  int capacityMomentCount = 0,
  int activationTarget = 3,
  bool fitIsPositive = false,
  bool fitIsUnclear = true,
  bool fitNotAnswered = true,
  int pullReasonRecordCount = 0,
  int outcomeRecordCount = 0,
  int laterCostRecordCount = 0,
  bool weeklyReviewAvailable = false,
  bool boundaryResponseSelected = false,
  bool boundaryResponseCopied = false,
  bool proInterestCaptured = false,
  bool dailyChangeDismissed = false,
}) =>
    BetaFeedbackResponseInput(
      capacityWedgeActive: capacityWedgeActive,
      capacityMomentCount: capacityMomentCount,
      activationTarget: activationTarget,
      fitIsPositive: fitIsPositive,
      fitIsUnclear: fitIsUnclear,
      fitNotAnswered: fitNotAnswered,
      pullReasonRecordCount: pullReasonRecordCount,
      outcomeRecordCount: outcomeRecordCount,
      laterCostRecordCount: laterCostRecordCount,
      weeklyReviewAvailable: weeklyReviewAvailable,
      boundaryResponseSelected: boundaryResponseSelected,
      boundaryResponseCopied: boundaryResponseCopied,
      proInterestCaptured: proInterestCaptured,
      dailyChangeDismissed: dailyChangeDismissed,
    );

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
    expect(
      lower,
      isNot(contains(_privateSnippet)),
      reason: 'must not expose private transcript text',
    );
  }
}

void main() {
  const engine = BetaFeedbackResponseEngine();
  late String playbook;

  setUpAll(() {
    playbook = File(_playbookPath).readAsStringSync();
  });

  group('BetaFeedbackResponseEngine failure mode mapping', () {
    test('unclear promise maps to onboarding copy fix', () {
      final result = engine.build(
        _input(
          capacityMomentCount: 3,
          fitIsUnclear: true,
          fitNotAnswered: true,
        ),
      );
      expect(result.issueId, BetaFeedbackIssueIds.unclearPromise);
      expect(
        result.suggestedNextFixLabel,
        BetaFeedbackResponseCopy.suggestedFixClarifyPromise,
      );
      expect(result.recommendedResponseSummary, contains('onboarding copy'));
      expect(result.recommendedResponseSummary, contains('See why you keep saying yes'));
    });

    test('first moment blocked maps to record/start flow fix', () {
      final result = engine.build(_input(capacityMomentCount: 0));
      expect(result.issueId, BetaFeedbackIssueIds.firstMomentBlocked);
      expect(
        result.suggestedNextFixLabel,
        BetaFeedbackResponseCopy.suggestedFixFirstRecordingCta,
      );
      expect(result.recommendedResponseSummary, contains('Save yes moment'));
    });

    test('activation dropoff maps to 3-moment path fix', () {
      final one = engine.build(_input(capacityMomentCount: 1));
      expect(one.issueId, BetaFeedbackIssueIds.activationDropoff);
      expect(one.recommendedResponseSummary, contains('N of 3 yes moments saved'));

      final two = engine.build(_input(capacityMomentCount: 2));
      expect(two.issueId, BetaFeedbackIssueIds.activationDropoff);
      expect(
        two.suggestedNextFixLabel,
        BetaFeedbackResponseCopy.suggestedFixActivationPath,
      );
    });

    test('repetitive loop maps to daily change sharpening', () {
      final result = engine.build(
        _input(
          capacityMomentCount: 3,
          fitIsUnclear: true,
          fitNotAnswered: true,
          dailyChangeDismissed: true,
        ),
      );
      expect(result.issueId, BetaFeedbackIssueIds.repetitiveLoop);
      expect(
        result.suggestedNextFixLabel,
        BetaFeedbackResponseCopy.suggestedFixDailyChange,
      );
      expect(result.recommendedResponseSummary, contains('Sharpen daily change'));
    });

    test('weak alternative maps to alternative rule improvement', () {
      final result = engine.build(
        _input(
          capacityMomentCount: 3,
          fitIsPositive: true,
          fitIsUnclear: false,
          fitNotAnswered: false,
          pullReasonRecordCount: 2,
          boundaryResponseSelected: false,
          boundaryResponseCopied: false,
        ),
      );
      expect(result.issueId, BetaFeedbackIssueIds.weakAlternative);
      expect(
        result.suggestedNextFixLabel,
        BetaFeedbackResponseCopy.suggestedFixAlternatives,
      );
      expect(result.recommendedResponseSummary, contains('alternative rules'));
    });

    test('paid signal maps to RevenueCat readiness, not RevenueCat enabled', () {
      final result = engine.build(
        _input(
          capacityMomentCount: 3,
          fitIsPositive: true,
          fitIsUnclear: false,
          fitNotAnswered: false,
          proInterestCaptured: true,
          weeklyReviewAvailable: true,
          outcomeRecordCount: 1,
        ),
      );
      expect(result.issueId, BetaFeedbackIssueIds.paidSignalReady);
      expect(
        result.suggestedNextFixLabel,
        BetaFeedbackResponseCopy.suggestedFixPaidLaunch,
      );
      expect(result.recommendedResponseSummary, contains('RevenueCat'));
      expect(result.recommendedResponseSummary, contains('Do not enable payments'));
      expect(result.whatNotToChangeSummary, contains('Do not enable RevenueCat'));
    });

    test('returns hidden when wedge inactive', () {
      final result = engine.build(_input(capacityWedgeActive: false));
      expect(result.hasRecommendation, isFalse);
      expect(result.suggestedNextFixLabel, isEmpty);
    });

    test('returns hidden when not enough evidence', () {
      final result = engine.build(
        _input(
          capacityMomentCount: 3,
          fitIsPositive: true,
          fitIsUnclear: false,
          fitNotAnswered: false,
          boundaryResponseSelected: true,
          pullReasonRecordCount: 1,
        ),
      );
      expect(result.hasRecommendation, isFalse);
    });
  });

  group('BETA_FEEDBACK_RESPONSE_PLAYBOOK.md', () {
    test('exists', () {
      expect(File(_playbookPath).existsSync(), isTrue);
    });

    test('docs say do not build all fixes at once', () {
      expect(playbook, contains('Do not build all fixes at once'));
    });

    test('docs say RevenueCat only after return + WTP signal', () {
      expect(playbook.toLowerCase(), contains('revenuecat only after return'));
      expect(playbook.toLowerCase(), contains('wtp'));
    });

    test('contains failure mode table columns', () {
      expect(playbook, contains('Beta feedback'));
      expect(playbook, contains('Likely product problem'));
      expect(playbook, contains('What to change'));
      expect(playbook, contains('What not to change'));
      expect(playbook, contains('Success signal'));
    });

    test('lists all issue IDs', () {
      for (final id in BetaFeedbackIssueIds.all) {
        expect(playbook, contains(id));
      }
    });
  });

  group('Copy safety', () {
    test('no private transcript text in visible copy', () {
      _expectNoBannedCopy(BetaFeedbackResponseCopy.allVisibleStrings());
    });

    test('no therapy / diagnosis / medical / treatment language', () {
      final combined =
          '${BetaFeedbackResponseCopy.allVisibleStrings().join('\n')}\n$playbook'
              .toLowerCase();
      for (final term in ['therapy', 'diagnosis', 'medical', 'treatment']) {
        expect(combined, isNot(contains(term)));
      }
    });

    test('no mental health score / wellbeing score / clinical score / life score',
        () {
      _expectNoBannedCopy(BetaFeedbackResponseCopy.allVisibleStrings());
    });

    test('no purchase CTAs or pro active claims in copy', () {
      for (final text in BetaFeedbackResponseCopy.allVisibleStrings()) {
        expect(text, isNot(contains('Buy now')));
        expect(text, isNot(contains('Subscribe now')));
        expect(text, isNot(contains('Pro is active')));
      }
    });

    test('no ArchiveMe knows in copy', () {
      for (final text in BetaFeedbackResponseCopy.allVisibleStrings()) {
        expect(text.toLowerCase(), isNot(contains('archiveme knows')));
      }
    });

    test('no streak language', () {
      _expectNoBannedCopy(BetaFeedbackResponseCopy.allVisibleStrings());
    });

    test('no PMF proven claim', () {
      final combined =
          '${BetaFeedbackResponseCopy.allVisibleStrings().join('\n')}\n$playbook'
              .toLowerCase();
      expect(combined, isNot(contains('pmf proven')));
      expect(combined, isNot(contains('product-market fit')));
      expect(combined, isNot(contains('product market fit')));
      expect(playbook.toLowerCase(), contains('not pmf proof'));
    });

    test('no fake stats or testimonials in copy', () {
      for (final text in BetaFeedbackResponseCopy.allVisibleStrings()) {
        expect(text, isNot(contains('testimonial')));
        expect(text, isNot(matches(RegExp(r'\d+%\s+of\s+users'))));
      }
    });
  });
}
