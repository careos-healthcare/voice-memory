import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _qaDocPath = 'docs/TESTFLIGHT_MANUAL_QA.md';
const _supportUrl = 'https://archiveme.app/contact';
const _bundleId = 'com.voicememory.mobile';

const _forbiddenPurchaseCtas = ['Buy now', 'Subscribe now', 'Pro is active'];

const _forbiddenClinicalTerms = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
];

void main() {
  late String doc;

  setUpAll(() {
    doc = File(_qaDocPath).readAsStringSync();
  });

  group('TESTFLIGHT_MANUAL_QA.md', () {
    test('exists with core release identity', () {
      expect(File(_qaDocPath).existsSync(), isTrue);
      expect(doc, contains('ArchiveMe'));
      expect(doc, contains(_bundleId));
      expect(doc, contains('ios/Runner.xcworkspace'));
      expect(doc, contains(_supportUrl));
      expect(doc, contains('0.2.0'));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final buildMatch = RegExp(r'version:\s*[\d.]+\+(\d+)').firstMatch(pubspec);
      expect(buildMatch, isNotNull, reason: 'pubspec version must include +build');
      expect(doc, contains(buildMatch!.group(1)!));
    });

    test('documents offline sync production evidence path', () {
      expect(doc, contains('Offline sync verify'));
      expect(doc, contains('DEVICE_EVIDENCE_RUNBOOK'));
    });

    test('warns against Runner.xcodeproj and states RevenueCat incomplete', () {
      expect(doc.toLowerCase(), contains('do not open'));
      expect(doc, contains('Runner.xcodeproj'));
      expect(
        doc.toLowerCase(),
        anyOf(
          contains('purchases are unavailable'),
          contains('purchases unavailable'),
        ),
      );
      expect(doc.toLowerCase(), contains('revenuecat'));
    });

    test('requires physical device and fresh install', () {
      expect(doc.toLowerCase(), contains('physical device'));
      expect(doc.toLowerCase(), contains('fresh install'));
    });

    test('covers capture flows', () {
      expect(doc.toLowerCase(), contains('typed moment'));
      expect(doc.toLowerCase(), contains('voice moment'));
    });

    test('covers sticky-loop surfaces', () {
      expect(doc, contains('First Week Path'));
      expect(doc, contains('Daily Archive Exercise'));
      expect(doc, contains("Today's One Question"));
      expect(doc, contains('Archive Clarity'));
      expect(doc, contains('Then vs Now'));
      expect(doc, contains('Archive Calendar'));
      expect(doc, contains('Review Ritual'));
      expect(doc, contains('Milestone Cards'));
    });

    test('covers beta and reviewer routes', () {
      expect(doc, contains('Sample Archive'));
      expect(doc, contains('Help & reviewer guide'));
      expect(doc, contains('Support & feedback'));
      expect(doc, contains('Pro Preview'));
      expect(doc, contains('Restore Purchases'));
    });

    test('covers privacy and share safety', () {
      expect(doc.toLowerCase(), contains('privacy controls'));
      expect(
        doc.toLowerCase(),
        anyOf(
          contains('no journal text'),
          contains('no private journal text'),
          contains('no journal text in share'),
        ),
      );
      expect(doc.toLowerCase(), contains('calendar'));
      expect(doc.toLowerCase(), contains('milestone'));
    });

    test('does not use forbidden purchase CTAs', () {
      for (final cta in _forbiddenPurchaseCtas) {
        expect(doc, isNot(contains(cta)));
      }
    });

    test(
      'does not recommend clinical or forbidden language in QA guidance',
      () {
        final lower = doc.toLowerCase();
        for (final term in _forbiddenClinicalTerms) {
          expect(
            lower,
            isNot(contains(term)),
            reason: 'QA doc must not contain "$term"',
          );
        }
      },
    );

    test('includes release decision checklist sections', () {
      expect(doc, contains('Internal TestFlight ready when'));
      expect(doc, contains('External TestFlight ready when'));
      expect(doc, contains('Pass/Fail'));
    });
  });
}