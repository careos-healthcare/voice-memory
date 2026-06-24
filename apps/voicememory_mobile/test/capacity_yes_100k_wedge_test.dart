import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _wedgePlanPath = 'docs/CAPACITY_YES_100K_WEDGE_PLAN.md';
const _landingPath = 'docs/CAPACITY_YES_LANDING_PAGE_COPY.md';
const _creatorPath = 'docs/CAPACITY_YES_CREATOR_SCRIPTS.md';
const _interviewPath = 'docs/CAPACITY_YES_BETA_INTERVIEW_SCRIPT.md';
const _appStorePath = 'docs/CAPACITY_YES_APP_STORE_TEST_COPY.md';

const _capacityOnlyPaths = [
  _wedgePlanPath,
  _landingPath,
  _creatorPath,
  _interviewPath,
  _appStorePath,
  'docs/CAPACITY_YES_POSITIONING_ONE_PAGER.md',
];

const _docPaths = [
  ..._capacityOnlyPaths,
  'docs/WEDGE_RETENTION_ACQUISITION_PLAN.md',
  'docs/BETA_RECRUITMENT_PACK.md',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Pro is active',
];

const _forbiddenClinicalTerms = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
];

const _forbiddenScoreTerms = [
  'mental health score',
  'wellbeing score',
  'life score',
  'clinical score',
];

const _forbiddenHypePhrases = [
  'fake testimonial',
  'fake stats',
  'join thousands',
  'thousands of users',
];

void main() {
  late String wedgePlan;
  late String landing;
  late String creator;
  late String interview;
  late String appStore;
  late String capacityDocs;
  late String allDocs;

  setUpAll(() {
    wedgePlan = File(_wedgePlanPath).readAsStringSync();
    landing = File(_landingPath).readAsStringSync();
    creator = File(_creatorPath).readAsStringSync();
    interview = File(_interviewPath).readAsStringSync();
    appStore = File(_appStorePath).readAsStringSync();
    capacityDocs =
        _capacityOnlyPaths.map((path) => File(path).readAsStringSync()).join('\n');
    allDocs = _docPaths.map((path) => File(path).readAsStringSync()).join('\n');
  });

  group('Capacity yes 100k wedge docs exist', () {
    test('all required docs exist', () {
      for (final path in _docPaths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('ArchiveMe identity and primary wedge', () {
      expect(allDocs, contains('ArchiveMe'));
      expect(
        allDocs.toLowerCase(),
        contains('people who keep taking on too much'),
      );
      expect(
        allDocs.toLowerCase(),
        anyOf(
          contains('saying yes when they have no capacity'),
          contains('saying yes when you have no capacity'),
          contains('say yes before checking capacity'),
          contains('start with one pattern'),
        ),
      );
      expect(allDocs.toLowerCase(), contains('private evidence archive'));
      expect(allDocs.toLowerCase(), contains('what keeps repeating'));
    });

    test('pattern and moment language', () {
      expect(allDocs.toLowerCase(), contains('what keeps repeating'));
      expect(allDocs.toLowerCase(), contains('save the moment'));
      expect(allDocs.toLowerCase(), contains('see the pattern'));
    });

    test('100k/month and pricing validation', () {
      expect(allDocs.toLowerCase(), contains('100k/month'));
      expect(allDocs.toLowerCase(), contains('pricing'));
      expect(wedgePlan, contains('£9.99'));
    });

    test('growth path gates documented', () {
      expect(wedgePlan.toLowerCase(), contains('20-user test'));
      expect(wedgePlan.toLowerCase(), contains('100-user test'));
      expect(wedgePlan.toLowerCase(), contains('1,000-user growth path'));
    });

    test('willingness to pay and interview pack', () {
      expect(allDocs.toLowerCase(), contains('willingness to pay'));
      expect(interview, contains('What made you save the first moment?'));
      expect(
        interview,
        contains('Did ArchiveMe show anything you did not expect?'),
      );
      expect(
        interview,
        contains('Would you open this before saying yes next time?'),
      );
      expect(
        interview,
        contains(
          'Would you pay to keep a long-term archive of this pattern?',
        ),
      );
      expect(
        interview,
        contains('At what price would this feel too expensive?'),
      );
      expect(interview, contains('What would make this a must-keep app?'));
    });

    test('creator landing and app store copy referenced', () {
      expect(wedgePlan, contains('CAPACITY_YES_CREATOR_SCRIPTS.md'));
      expect(wedgePlan, contains('CAPACITY_YES_LANDING_PAGE_COPY.md'));
      expect(wedgePlan, contains('CAPACITY_YES_APP_STORE_TEST_COPY.md'));
      expect(creator.toLowerCase(), contains('short-form video'));
      expect(landing, contains('See why you keep saying yes.'));
      expect(appStore.toLowerCase(), contains('subtitle'));
    });

    test('required landing headline variants', () {
      expect(landing, contains('See why you keep saying yes.'));
      expect(landing, contains('A private archive for overcommitment patterns.'));
      expect(
        landing,
        contains('Stop guessing why you keep taking on too much.'),
      );
      expect(landing, contains('Save the moment. See the pattern.'));
      expect(landing, contains('ArchiveMe shows what keeps repeating.'));
    });
  });

  group('Copy safety in capacity yes pack', () {
    test('no forbidden purchase CTAs in capacity docs', () {
      for (final cta in _forbiddenPurchaseCtas) {
        expect(capacityDocs, isNot(contains(cta)));
      }
    });

    test('no clinical terms in growth docs', () {
      final lower = capacityDocs.toLowerCase();
      for (final term in _forbiddenClinicalTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no forbidden score language', () {
      final lower = capacityDocs.toLowerCase();
      for (final term in _forbiddenScoreTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no fake testimonials or invented user counts', () {
      final lower = capacityDocs.toLowerCase();
      for (final phrase in _forbiddenHypePhrases) {
        expect(lower, isNot(contains(phrase)), reason: 'must not contain $phrase');
      }
    });
  });
}
