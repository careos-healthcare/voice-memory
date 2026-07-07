import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/features/three_day_challenge/three_day_challenge_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

const _bannedTerms = [
  'diagnosis',
  'treatment',
  'therapy',
  'clinical',
  'medical report',
  'cloud backup included',
  'sync is active',
  'your archive is backed up',
  'better ai',
  'more ai',
  'guaranteed transformation',
  'live backup',
  'cloud backup guarantee',
];

List<String> _continuityCopyBlob() => [
      ThreeDayChallengeCopy.title,
      ThreeDayChallengeCopy.day1Title,
      ThreeDayChallengeCopy.day2Title,
      ThreeDayChallengeCopy.day3Title,
      ConsumerUiCopy.paywallHeadline,
      ConsumerUiCopy.paywallPrimaryCta,
      ArchivePaywallCopy.proActiveConfirmation,
      ConsumerUiCopy.paywallDifferentiation,
      ConsumerUiCopy.paywallTrust,
      ConsumerUiCopy.paywallBackupLine,
    ];

void main() {
  group('Landing and app continuity copy alignment', () {
    test('website and app promises stay aligned', () {
      expect(ThreeDayChallengeCopy.title, '3-day proof challenge');
      expect(ThreeDayChallengeCopy.day1Title, contains('Day 1'));
      expect(ThreeDayChallengeCopy.day2Title, contains('Day 2'));
      expect(ThreeDayChallengeCopy.day3Title, contains('Day 3'));
      expect(ConsumerUiCopy.paywallHeadline, 'Keep the longer story.');
      expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep my longer story');
      expect(
        ArchivePaywallCopy.proActiveConfirmation,
        contains('keep the longer story'),
      );
    });

    test('continuity copy guard blocks banned positioning', () {
      final blob = _continuityCopyBlob().join(' ').toLowerCase();
      for (final banned in _bannedTerms) {
        if (banned == 'therapy') continue;
        expect(blob, isNot(contains(banned)), reason: 'must not contain $banned');
      }
      expect(blob, contains('not therapy'));
      expect(blob, contains('do not rely on this build as cloud backup'));
      expect(blob, isNot(contains('more ai')));
    });

    test('continuity checklist doc exists with required promises', () {
      final doc = File('docs/release/LANDING_APP_CONTINUITY_CHECKLIST.md')
          .readAsStringSync();
      expect(doc.toLowerCase(), contains('3-day proof challenge'));
      expect(doc, contains('Day 1'));
      expect(doc, contains('Day 2'));
      expect(doc, contains('Day 3'));
      expect(doc, contains('Keep the longer story'));
      expect(doc.toLowerCase(), contains('evidence'));
      expect(doc.toLowerCase(), contains('not therapy'));
      expect(doc.toLowerCase(), contains('cloud backup'));
      expect(doc.toLowerCase(), isNot(contains('more AI')));
    });
  });
}
