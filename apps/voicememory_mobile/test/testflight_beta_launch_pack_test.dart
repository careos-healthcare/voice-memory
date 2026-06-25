import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _betaLaunchPlanPath = 'docs/TESTFLIGHT_BETA_LAUNCH_PLAN.md';
const _testerMessagePath = 'docs/BETA_TESTER_MESSAGE.md';
const _interviewScriptPath = 'docs/BETA_INTERVIEW_SCRIPT_CAPACITY.md';
const _submissionChecklistPath = 'docs/TESTFLIGHT_SUBMISSION_CHECKLIST.md';

const _docPaths = [
  _betaLaunchPlanPath,
  _testerMessagePath,
  _interviewScriptPath,
  _submissionChecklistPath,
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Pro is active',
  'ArchiveMe knows',
];

const _forbiddenClinicalTerms = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
];

void main() {
  late Map<String, String> docs;

  setUpAll(() {
    docs = {
      for (final path in _docPaths) path: File(path).readAsStringSync(),
    };
  });

  group('TestFlight beta launch pack docs exist', () {
    for (final path in _docPaths) {
      test(path, () {
        expect(File(path).existsSync(), isTrue);
      });
    }
  });

  group('TESTFLIGHT_BETA_LAUNCH_PLAN.md', () {
    late String plan;

    setUp(() => plan = docs[_betaLaunchPlanPath]!);

    test('contains success targets', () {
      expect(plan, contains('20'));
      expect(plan.toLowerCase(), contains('20 beta users'));
      expect(plan, contains('10'));
      expect(plan.toLowerCase(), contains('first yes moment'));
      expect(plan, contains('5'));
      expect(plan.toLowerCase(), contains('3 yes moments'));
      expect(plan.toLowerCase(), contains('day 7'));
      expect(plan.toLowerCase(), contains('fits or partly fits'));
      expect(plan.toLowerCase(), contains('would pay'));
    });

    test('contains core promise and beta mission', () {
      expect(plan, contains('Catch the yes before it costs you'));
      expect(plan, contains('Save 3 yes moments'));
      expect(plan, contains('Review your yes loop'));
      expect(plan, contains('Tell us if it fits'));
    });
  });

  group('BETA_TESTER_MESSAGE.md', () {
    late String message;

    setUp(() => message = docs[_testerMessagePath]!);

    test('contains required tester wording', () {
      expect(
        message,
        contains('private mind map of what keeps repeating in your life'),
      );
      expect(
        message,
        contains(
          'Start with one pattern — saying yes when you have no capacity',
        ),
      );
      expect(message, contains('Use it for 7 days'));
      expect(message, contains('Save 3 real moments'));
      expect(message, contains('Then review your yes loop and tell me if it fits'));
      expect(message, contains('Skip anything that does not apply'));
      expect(message, contains('Catch the yes before it costs you'));
    });
  });

  group('BETA_INTERVIEW_SCRIPT_CAPACITY.md', () {
    late String script;

    setUp(() => script = docs[_interviewScriptPath]!);

    test('contains 10 interview questions', () {
      expect(script, contains('What did you think the app was for in the first 30 seconds'));
      expect(script, contains('Catch the yes before it costs you'));
      expect(script, contains('Did you save a real yes moment'));
      expect(script, contains('What stopped you if not'));
      expect(script, contains('Did the 3-moment path feel clear'));
      expect(script, contains('Did the yes loop feel accurate'));
      expect(script, contains('Which part felt useful'));
      expect(script, contains('Which part felt confusing'));
      expect(script, contains('Would you use this again next week'));
      expect(
        script,
        contains('Would you pay to keep a private archive of this pattern'),
      );
    });
  });

  group('TESTFLIGHT_SUBMISSION_CHECKLIST.md', () {
    late String checklist;

    setUp(() => checklist = docs[_submissionChecklistPath]!);

    test('requires Runner.xcworkspace', () {
      expect(checklist, contains('Runner.xcworkspace'));
    });

    test('does not instruct opening Runner.xcodeproj', () {
      expect(checklist.toLowerCase(), isNot(contains('open runner.xcodeproj')));
      expect(checklist.toLowerCase(), isNot(contains('open `runner.xcodeproj`')));
    });

    test('contains identity and payment pause checks', () {
      expect(checklist, contains('ArchiveMe'));
      expect(checklist, contains('com.voicememory.mobile'));
      expect(checklist, contains('https://careosapp.co.uk/archiveme-support'));
      expect(checklist.toLowerCase(), contains('revenuecat'));
      expect(checklist.toLowerCase(), contains('no paid claims'));
    });
  });

  group('Copy safety across beta launch pack docs', () {
    test('does not contain forbidden purchase CTAs', () {
      final combined = docs.values.join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(combined, isNot(contains(cta)));
      }
    });

    test('does not contain clinical or forbidden language', () {
      final combined = docs.values.join('\n').toLowerCase();
      for (final term in _forbiddenClinicalTerms) {
        expect(
          combined,
          isNot(contains(term)),
          reason: 'Beta launch pack must not contain "$term"',
        );
      }
    });
  });
}
