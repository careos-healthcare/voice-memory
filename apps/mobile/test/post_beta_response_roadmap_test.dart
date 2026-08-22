import 'dart:io';

import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const _roadmapPath = '../../docs/POST_BETA_RESPONSE_ROADMAP.md';
const _betaFourPath = '../../docs/BETA_FOUR_FAILURE_RESPONSE_RULES.md';
const _testflightPath = 'docs/TESTFLIGHT_BETA_LAUNCH_PLAN.md';
const _paidPath = 'docs/PAID_LAUNCH_DECISION_CHECKLIST.md';
const _dependencyPath = 'docs/DEPENDENCY_MAINTENANCE_PLAN.md';

const _bannedPhrases = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
  'mental health score',
  'wellbeing score',
  'clinical score',
  'life score',
  'archiveme knows',
  'fake stats',
  'testimonial',
  'everything stays on device',
  'fully encrypted archive',
  '100% secure',
  'unhackable',
];

const _privateSnippet = 'felt pressure at work before saying yes';

/// Each failure signal must map to exactly one branch slug in the roadmap.
const _failureToBranch = <String, String>{
  'users do not understand': 'onboarding-clarity-post-beta',
  'save once but not 3': 'activation-simplification-post-beta',
  'daily change feels obvious': 'daily-change-rules-post-beta',
  'alternatives feel weak': 'fixed-alternatives-post-beta',
  'quick capture still feels like work': 'one-tap-capture-post-beta',
  '2–3 would pay': 'revenuecat-readiness-post-beta',
  'forget to return': 'local-review-ritual-post-beta',
  'broader patterns': 'second-guided-path-post-beta',
  'worry about privacy': 'metadata-privacy-hardening-post-beta',
  'reviewers struggle': 'app-review-path-polish-post-beta',
};

bool _isProhibitionLine(String lower) {
  return lower.contains('forbidden') ||
      lower.contains('do not claim') ||
      lower.contains('do not use') ||
      lower.contains('guardrail') ||
      lower.contains('no therapy /') ||
      lower.contains('coaching / therapy') ||
      lower.contains('therapy / medical') ||
      lower.contains('unless true') ||
      RegExp(
        r'\bno\s+(therapy|diagnosis|medical|treatment|mental|wellbeing|clinical|life)\b',
      ).hasMatch(lower);
}

bool _skipPrivacyScan(String lower) {
  return lower.contains('do not overclaim encryption') ||
      lower.contains('do not claim everything stays on device') ||
      lower.contains('encrypt more metadata') ||
      lower.contains('encrypt selected prefs') ||
      lower.contains('encryption key store') ||
      lower.contains('metadata-privacy-hardening') ||
      lower.contains('journal migration') ||
      lower.contains('bundle id') ||
      lower.contains('application id') ||
      lower.contains('workspace') ||
      lower.contains('url scheme') ||
      lower.contains('app group');
}

void _expectNoBannedCopy(String text, {bool checkPrivacyPolicy = true}) {
  final lines = text.split('\n');
  for (final line in lines) {
    final lower = line.toLowerCase();
    final isProhibitionLine = _isProhibitionLine(lower);
    for (final phrase in _bannedPhrases) {
      if (isProhibitionLine) continue;
      if (lower.trim().startsWith('- no ') && lower.contains(phrase)) continue;
      if (lower.trim().startsWith('-') &&
          RegExp('[“"‘]').hasMatch(line) &&
          lower.contains(phrase)) {
        continue;
      }
      if (phrase == 'therapy' &&
          (lower.contains('no therapy') || lower.contains('not therapy'))) {
        continue;
      }
      expect(
        lower,
        isNot(contains(phrase)),
        reason: '"$line" contains "$phrase"',
      );
    }
    if (!isProhibitionLine && checkPrivacyPolicy && !_skipPrivacyScan(lower)) {
      expect(lower, isNot(contains(_privateSnippet)));
      for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
        fail('privacy violation in "$line": $reason');
      }
    } else if (!isProhibitionLine) {
      expect(lower, isNot(contains(_privateSnippet)));
    }
  }
}

void main() {
  late String roadmap;
  late String betaFour;
  late String testflight;
  late String paid;
  late String dependency;

  setUpAll(() {
    roadmap = File(_roadmapPath).readAsStringSync();
    betaFour = File(_betaFourPath).readAsStringSync();
    testflight = File(_testflightPath).readAsStringSync();
    paid = File(_paidPath).readAsStringSync();
    dependency = File(_dependencyPath).readAsStringSync();
  });

  group('Roadmap doc exists', () {
    test('POST_BETA_RESPONSE_ROADMAP.md exists', () {
      expect(File(_roadmapPath).existsSync(), isTrue);
      expect(roadmap, contains('Post-Beta Response Roadmap'));
    });
  });

  group('One branch per failure signal', () {
    test('each beta failure maps to one branch only', () {
      for (final entry in _failureToBranch.entries) {
        expect(
          roadmap.toLowerCase(),
          contains(entry.value),
          reason: 'missing branch for ${entry.key}',
        );
      }
      final branchSlugs = _failureToBranch.values.toList();
      expect(branchSlugs.toSet().length, branchSlugs.length);
    });

    test('onboarding confusion maps only to onboarding copy scope', () {
      expect(roadmap, contains('onboarding-clarity-post-beta'));
      expect(roadmap.toLowerCase(), contains('onboarding copy only'));
      expect(roadmap.toLowerCase(), contains('headline / body copy'));
      expect(roadmap.toLowerCase(), contains('how-it-works dialog'));
    });

    test('one-to-three dropoff maps only to activation simplification', () {
      expect(roadmap, contains('activation-simplification-post-beta'));
      expect(roadmap.toLowerCase(), contains('activation flow only'));
      expect(roadmap.toLowerCase(), contains('1/3 and 2/3 card copy'));
    });

    test('obvious daily change maps only to daily change rules', () {
      expect(roadmap, contains('daily-change-rules-post-beta'));
      expect(roadmap.toLowerCase(), contains('daily change rules only'));
      expect(roadmap.toLowerCase(), contains('response categories'));
    });

    test('weak alternatives maps only to fixed alternatives', () {
      expect(roadmap, contains('fixed-alternatives-post-beta'));
      expect(roadmap.toLowerCase(), contains('fixed alternatives only'));
      expect(roadmap.toLowerCase(), contains('pull-specific labels'));
    });

    test('quick capture workload maps only to one-tap capture', () {
      expect(roadmap, contains('one-tap-capture-post-beta'));
      expect(roadmap.toLowerCase(), contains('one-tap'));
      expect(roadmap.toLowerCase(), contains('fewer taps'));
    });

    test('2–3 paid-intent users maps to RevenueCat readiness', () {
      expect(roadmap, contains('revenuecat-readiness-post-beta'));
      expect(roadmap.toLowerCase(), contains('2–3 clear paid-intent users'));
      expect(roadmap.toLowerCase(), contains('sandbox purchase'));
    });

    test('forgetting to return maps to local review ritual', () {
      expect(roadmap, contains('local-review-ritual-post-beta'));
      expect(roadmap.toLowerCase(), contains('local reminder'));
      expect(roadmap.toLowerCase(), contains('no push notification backend'));
    });

    test('broader pattern requests map to second guided path', () {
      expect(roadmap, contains('second-guided-path-post-beta'));
      expect(roadmap.toLowerCase(), contains('thoughts that keep looping'));
      expect(roadmap.toLowerCase(), contains('second guided path'));
    });

    test('privacy worry maps to metadata privacy hardening', () {
      expect(roadmap, contains('metadata-privacy-hardening-post-beta'));
      expect(roadmap.toLowerCase(), contains('encrypt selected prefs'));
    });

    test('reviewer struggle maps to app review path polish', () {
      expect(roadmap, contains('app-review-path-polish-post-beta'));
      expect(roadmap.toLowerCase(), contains('reviewer notes'));
    });
  });

  group('Roadmap gates', () {
    test('says do not build all branches at once', () {
      expect(roadmap.toLowerCase(), contains('do not build all branches'));
    });

    test('says no RevenueCat before 2–3 clear paid-intent users', () {
      expect(roadmap.toLowerCase(), contains('do not enable revenuecat'));
      expect(roadmap.toLowerCase(), contains('2–3 clear paid-intent users'));
    });

    test('says no new dashboards for these fixes', () {
      expect(roadmap.toLowerCase(), contains('do not add new dashboards'));
    });
  });

  group('Cross-doc links', () {
    test('beta four failure rules references post-beta roadmap', () {
      expect(betaFour.toLowerCase(), contains('post_beta_response_roadmap'));
    });

    test('testflight plan references post-beta roadmap', () {
      expect(testflight.toLowerCase(), contains('post_beta_response_roadmap'));
    });

    test('paid checklist references post-beta roadmap', () {
      expect(paid.toLowerCase(), contains('post_beta_response_roadmap'));
    });

    test('dependency plan references post-beta roadmap', () {
      expect(dependency.toLowerCase(), contains('post_beta_response_roadmap'));
    });
  });

  group('Dependency maintenance deferral', () {
    test(
      'plan says no upgrades before TestFlight unless crash/store/security blocker',
      () {
        final lower = dependency.toLowerCase();
        expect(lower, contains('deferred during testflight'));
        expect(lower, contains('crash'));
        expect(lower, contains('app store rejection'));
        expect(lower, contains('critical security'));
      },
    );

    test('RevenueCat upgrade tied to RevenueCat readiness branch', () {
      expect(dependency.toLowerCase(), contains('revenuecat readiness branch'));
      expect(dependency.toLowerCase(), contains('paid-intent proof'));
    });

    test('notification upgrade tied to local review ritual branch', () {
      expect(dependency.toLowerCase(), contains('local review ritual branch'));
    });

    test('record upgrade tied to audio QA branch', () {
      expect(dependency.toLowerCase(), contains('post-beta audio qa branch'));
    });
  });

  group('Guardrails', () {
    test('roadmap passes banned phrase scan', () {
      _expectNoBannedCopy(roadmap);
    });

    test('updated docs pass banned phrase scan', () {
      _expectNoBannedCopy(betaFour);
      _expectNoBannedCopy(testflight);
      _expectNoBannedCopy(paid);
      _expectNoBannedCopy(dependency, checkPrivacyPolicy: false);
    });
  });
}