import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/features/landing_continuity/landing_app_continuity_copy.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_copy.dart';
import 'package:voicememory_mobile/features/revenue_foundation/revenue_value_copy.dart';
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
      ...LandingAppContinuityCopy.allVisibleStrings(),
      ThreeDayChallengeCopy.title,
      ThreeDayChallengeCopy.day1Title,
      ThreeDayChallengeCopy.day2Title,
      ThreeDayChallengeCopy.day3Title,
      ConsumerUiCopy.paywallHeadline,
      ConsumerUiCopy.paywallPrimaryCta,
      ConsumerUiCopy.paywallPrimaryValueBlock,
      ArchivePaywallCopy.proActiveConfirmation,
      ConsumerUiCopy.paywallDifferentiation,
      ConsumerUiCopy.paywallTrust,
      ConsumerUiCopy.paywallBackupLine,
      RevenueValueCopy.chatGptDifferentiationLine,
      ProEvidenceValueCopy.chatGptDifferentiationLine,
    ];

void main() {
  group('Landing and app continuity copy alignment', () {
    test('website and app promises stay aligned', () {
      expect(
        LandingAppContinuityCopy.hero,
        'When it repeats, save it',
      );
      expect(
        LandingAppContinuityCopy.subheadline,
        'No daily journal. No streak. No dashboard to maintain.',
      );
      expect(
        LandingAppContinuityCopy.chatGptDifferentiation,
        'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.',
      );
      expect(
        LandingAppContinuityCopy.proPaidReason,
        'Pro keeps the longer proof trail over time.',
      );
      expect(
        LandingAppContinuityCopy.freePositioning,
        'Free shows the first useful proof. Pro keeps the longer proof trail.',
      );
      expect(
        LandingAppContinuityCopy.howItWorksStepTitles,
        [
          'Save one real moment',
          'Come back when it repeats',
          'See what appeared and returned',
          'Correct what is not relevant',
          'Keep the longer proof trail with Pro',
        ],
      );

      expect(ThreeDayChallengeCopy.title, LandingAppContinuityCopy.hero);
      expect(ThreeDayChallengeCopy.day1Title, LandingAppContinuityCopy.step1Title);
      expect(ThreeDayChallengeCopy.day2Title, LandingAppContinuityCopy.step2Title);
      expect(ThreeDayChallengeCopy.day3Title, LandingAppContinuityCopy.step3Title);

      expect(ConsumerUiCopy.paywallHeadline, PaywallAlignmentCopy.headline);
      expect(ConsumerUiCopy.paywallHeadline, 'Keep the longer proof trail');
      expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep the longer trail');
      expect(
        ConsumerUiCopy.paywallPrimaryValueBlock,
        PaywallAlignmentCopy.secondaryReassurance,
      );
      expect(
        ArchivePaywallCopy.proActiveConfirmation,
        contains('keeps the longer proof trail'),
      );
      expect(
        RevenueValueCopy.chatGptDifferentiationLine,
        LandingAppContinuityCopy.chatGptDifferentiation,
      );
      expect(
        ProEvidenceValueCopy.chatGptDifferentiationLine,
        LandingAppContinuityCopy.chatGptDifferentiation,
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
      expect(doc, contains('When it repeats, save it'));
      expect(doc, contains('No daily journal. No streak. No dashboard to maintain.'));
      expect(doc, contains('Save one real moment'));
      expect(doc, contains('Come back when it repeats'));
      expect(doc, contains('See what appeared and returned'));
      expect(doc, contains('Correct what is not relevant'));
      expect(doc, contains('Keep the longer proof trail with Pro'));
      expect(
        doc,
        contains(
          'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.',
        ),
      );
      expect(doc, contains('Keep the longer proof trail'));
      expect(
        doc,
        contains('Free shows the first useful proof. Pro keeps the longer proof trail.'),
      );
      expect(doc.toLowerCase(), contains('not therapy'));
      expect(doc.toLowerCase(), contains('cloud backup'));
      expect(doc, contains('No **more AI** positioning'));
    });
  });
}
