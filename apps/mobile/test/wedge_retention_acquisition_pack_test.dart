import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _wedgePlanPath = 'docs/WEDGE_RETENTION_ACQUISITION_PLAN.md';
const _recruitmentPath = 'docs/BETA_RECRUITMENT_PACK.md';
const _retentionPath = 'docs/RETENTION_METRIC_DEFINITIONS.md';
const _paidLaunchPath = 'docs/PAID_LAUNCH_DECISION_CHECKLIST.md';
const _betaInviteCopyPath = 'lib/features/beta_invite/beta_invite_copy.dart';

const List<String> _docPaths = [
  _wedgePlanPath,
  _recruitmentPath,
  _retentionPath,
  _paidLaunchPath,
];

const _forbiddenPurchaseCtas = ['Buy now', 'Subscribe now', 'Pro is active'];

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

const _forbiddenHypeTerms = [
  'limited time',
  "don't miss",
  'thousands of users',
  'join thousands',
  'viral',
];

void main() {
  late String wedgePlan;
  late String recruitment;
  late String retention;
  late String paidLaunch;
  late String betaInviteCopy;
  late String allDocs;

  setUpAll(() {
    wedgePlan = File(_wedgePlanPath).readAsStringSync();
    recruitment = File(_recruitmentPath).readAsStringSync();
    retention = File(_retentionPath).readAsStringSync();
    paidLaunch = File(_paidLaunchPath).readAsStringSync();
    betaInviteCopy = File(_betaInviteCopyPath).readAsStringSync();
    allDocs = [wedgePlan, recruitment, retention, paidLaunch].join('\n');
  });

  group('Wedge retention acquisition docs exist', () {
    test('all required docs exist', () {
      for (final path in _docPaths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('positioning and ArchiveMe identity', () {
      expect(allDocs, contains('ArchiveMe'));
      expect(allDocs.toLowerCase(), contains('private evidence archive'));
      expect(
        allDocs.toLowerCase(),
        anyOf(contains('keeps returning'), contains('what returned')),
      );
      expect(allDocs.toLowerCase(), contains('what changed'));
      expect(allDocs.toLowerCase(), contains('what to watch next'));
    });

    test('primary and secondary wedge language', () {
      expect(
        allDocs.toLowerCase(),
        anyOf(
          contains('saying yes when they have no capacity'),
          contains('saying yes with no capacity'),
          contains('say yes before checking'),
        ),
      );
      expect(
        allDocs.toLowerCase(),
        anyOf(
          contains('prove they are doing enough'),
          contains('prove enough'),
          contains('doing enough'),
        ),
      );
    });

    test('20-user beta and 3 real moments', () {
      expect(allDocs.toLowerCase(), contains('20-user beta'));
      expect(allDocs.toLowerCase(), contains('3 real moments'));
    });

    test('retention and WTP metrics documented', () {
      expect(retention.toLowerCase(), contains('day-2 return'));
      expect(retention.toLowerCase(), contains('day-7 return'));
      expect(allDocs.toLowerCase(), contains('willingness to pay'));
      expect(allDocs.toLowerCase(), contains('willingness-to-pay'));
    });

    test('paid launch decision checklist referenced', () {
      expect(wedgePlan, contains('PAID_LAUNCH_DECISION_CHECKLIST.md'));
      expect(paidLaunch.toLowerCase(), contains('greenlight'));
      expect(paidLaunch.toLowerCase(), contains('no-go'));
    });

    test('RevenueCat not ready until configured', () {
      expect(
        allDocs.toLowerCase(),
        anyOf(
          contains('revenuecat'),
          contains('purchases are unavailable'),
          contains('not ready until'),
        ),
      );
      expect(allDocs.toLowerCase(), contains('revenuecat'));
    });
  });

  group('Copy safety in growth docs', () {
    test('no forbidden purchase CTAs', () {
      for (final cta in _forbiddenPurchaseCtas) {
        expect(allDocs, isNot(contains(cta)));
      }
    });

    test('no clinical terms in growth docs', () {
      final lower = allDocs.toLowerCase();
      for (final term in _forbiddenClinicalTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no forbidden score language', () {
      final lower = allDocs.toLowerCase();
      for (final term in _forbiddenScoreTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no fake urgency or fake social proof', () {
      final lower = allDocs.toLowerCase();
      for (final term in _forbiddenHypeTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });
  });

  group('Acquisition cohort documentation', () {
    test('wedge plan documents cohort routes', () {
      expect(wedgePlan, contains('capacity_yes_direct'));
      expect(wedgePlan, contains('prove_enough_direct'));
      expect(wedgePlan, contains('/start/capacity-yes'));
      expect(wedgePlan, contains('/start/prove-enough'));
      expect(wedgePlan, contains('generic_archive'));
    });
  });

  group('Beta invite in-app checklist', () {
    test('beta success checklist in copy', () {
      expect(betaInviteCopy, contains('Beta success means'));
      expect(betaInviteCopy.toLowerCase(), contains('real moments'));
      expect(betaInviteCopy.toLowerCase(), contains('return'));
      expect(betaInviteCopy.toLowerCase(), contains('review what'));
      expect(betaInviteCopy.toLowerCase(), contains('returned'));
    });
  });
}