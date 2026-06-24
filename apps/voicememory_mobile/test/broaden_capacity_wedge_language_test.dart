import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _capacityDocPaths = [
  'docs/CAPACITY_YES_100K_WEDGE_PLAN.md',
  'docs/CAPACITY_YES_LANDING_PAGE_COPY.md',
  'docs/CAPACITY_YES_CREATOR_SCRIPTS.md',
  'docs/CAPACITY_YES_BETA_INTERVIEW_SCRIPT.md',
  'docs/CAPACITY_YES_APP_STORE_TEST_COPY.md',
  'docs/CAPACITY_YES_POSITIONING_ONE_PAGER.md',
];

const _supportDocPaths = [
  'docs/WEDGE_RETENTION_ACQUISITION_PLAN.md',
  'docs/BETA_RECRUITMENT_PACK.md',
  'docs/PAID_LAUNCH_DECISION_CHECKLIST.md',
  'README.md',
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
  late String capacityDocs;
  late String allDocs;

  setUpAll(() {
    final parts = [..._capacityDocPaths, ..._supportDocPaths]
        .map((path) => File(path).readAsStringSync())
        .toList();
    capacityDocs = _capacityDocPaths
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    allDocs = parts.join('\n');
  });

  group('Broaden capacity wedge language docs', () {
    test('required docs exist', () {
      for (final path in [..._capacityDocPaths, ..._supportDocPaths]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('broad product and launch wedge language', () {
      expect(
        allDocs.toLowerCase(),
        contains('archiveme shows what keeps repeating'),
      );
      expect(allDocs.toLowerCase(), contains('start with one pattern'));
      expect(
        allDocs.toLowerCase(),
        contains('saying yes when you have no capacity'),
      );
    });

    test('behavior-led audience not professional-only', () {
      expect(
        allDocs.toLowerCase(),
        contains('people who keep taking on too much'),
      );
      expect(allDocs.toLowerCase(), contains('students'));
      expect(allDocs.toLowerCase(), contains('anyone who keeps overcommitting'));
    });

    test('central headline and product line', () {
      expect(allDocs, contains('See why you keep saying yes.'));
      expect(
        allDocs.toLowerCase(),
        contains(
          'archiveme helps you save real moments and spot repeated overcommitment patterns over time',
        ),
      );
      expect(
        allDocs.toLowerCase(),
        contains('private evidence archive for what keeps repeating'),
      );
    });

    test('100k maths and growth paths retained', () {
      expect(capacityDocs.toLowerCase(), contains('100k/month'));
      expect(capacityDocs.toLowerCase(), contains('pricing'));
      expect(capacityDocs, contains('£9.99'));
      expect(capacityDocs.toLowerCase(), contains('20-user test'));
      expect(capacityDocs.toLowerCase(), contains('100-user test'));
      expect(capacityDocs.toLowerCase(), contains('1,000-user growth path'));
    });

    test('does not use busy professionals as main target', () {
      expect(allDocs.toLowerCase(), isNot(contains('for busy professionals')));
      expect(allDocs.toLowerCase(), isNot(contains('busy professionals who')));
    });

    test('does not use overcommitted professionals as sole target', () {
      expect(
        allDocs.toLowerCase(),
        isNot(contains('for overcommitted professionals —')),
      );
      expect(
        allDocs.toLowerCase(),
        isNot(contains('archiveme helps overcommitted professionals save')),
      );
      expect(
        allDocs.toLowerCase(),
        isNot(
          contains(
            'for overcommitted professionals who keep saying yes',
          ),
        ),
      );
    });
  });

  group('Copy safety in broadened wedge docs', () {
    test('no forbidden purchase CTAs in capacity docs', () {
      for (final cta in _forbiddenPurchaseCtas) {
        expect(capacityDocs, isNot(contains(cta)));
      }
    });

    test('no clinical terms', () {
      final lower = allDocs.toLowerCase();
      for (final term in _forbiddenClinicalTerms) {
        if (term == 'therapy' && lower.contains('not a therapy')) continue;
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no forbidden score language', () {
      final lower = allDocs.toLowerCase();
      for (final term in _forbiddenScoreTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no fake testimonials or invented user counts', () {
      final lower = allDocs.toLowerCase();
      for (final phrase in _forbiddenHypePhrases) {
        expect(lower, isNot(contains(phrase)), reason: 'must not contain $phrase');
      }
    });
  });
}
