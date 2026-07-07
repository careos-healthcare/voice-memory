import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:voicememory_mobile/features/beta_invite/beta_invite_copy.dart';
import 'package:voicememory_mobile/product/acquisition_start_copy.dart';
import 'package:voicememory_mobile/product/archive_positioning_copy.dart';
import 'package:voicememory_mobile/product/loop_acquisition_copy.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';

const _onePagerPath = 'docs/CAPACITY_YES_POSITIONING_ONE_PAGER.md';
const _scorecardPath = 'docs/CAPACITY_YES_BETA_SCORECARD.md';

const _wedgeCopyPaths = [
  'lib/product/acquisition_start_copy.dart',
  'lib/product/loop_acquisition_copy.dart',
  'lib/product/loop_mode_copy.dart',
  'lib/features/beta_invite/beta_invite_copy.dart',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Pro is active',
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

const _forbiddenClinicalTerms = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
];

bool _hasForbiddenClinicalClaim(String text) {
  final lower = text.toLowerCase();
  for (final term in _forbiddenClinicalTerms) {
    if (!lower.contains(term)) continue;
    if (RegExp('not $term').hasMatch(lower)) continue;
    if (RegExp('not a $term').hasMatch(lower)) continue;
    return true;
  }
  return false;
}

void main() {
  late String onePager;
  late String scorecard;
  late String wedgeDartSources;

  setUpAll(() {
    onePager = File(_onePagerPath).readAsStringSync();
    scorecard = File(_scorecardPath).readAsStringSync();
    wedgeDartSources = _wedgeCopyPaths
        .map((path) => File(path).readAsStringSync())
        .join('\n');
  });

  group('Capacity yes wedge sharpening docs', () {
    test('positioning one-pager and scorecard exist', () {
      expect(File(_onePagerPath).existsSync(), isTrue);
      expect(File(_scorecardPath).existsSync(), isTrue);
    });

    test('required final wording in one-pager', () {
      expect(onePager, contains('See why you keep saying yes.'));
      expect(
        onePager.toLowerCase(),
        contains('private evidence archive for overcommitment patterns'),
      );
      expect(onePager.toLowerCase(), contains('overcommitted professionals'));
      expect(onePager, contains('Save one moment'));
    });

    test('one-pager covers first session and day 7', () {
      expect(onePager.toLowerCase(), contains('first 3 moments'));
      expect(onePager.toLowerCase(), contains('day 7'));
    });

    test('scorecard pricing and greenlight rules', () {
      expect(scorecard, contains('£9.99'));
      expect(scorecard, contains('£14.99'));
      expect(scorecard, contains('£19.99'));
      expect(scorecard.toLowerCase(), contains('greenlight'));
      expect(scorecard.toLowerCase(), contains('no-go'));
      expect(scorecard, contains('5/20 save 3 moments'));
      expect(scorecard, contains('10/20 save 3 moments'));
      expect(scorecard.toLowerCase(), contains('fewer than 3/20 save 3 moments'));
    });
  });

  group('Capacity yes in-app wedge copy', () {
    test('acquisition start copy matches headline and promise', () {
      expect(
        AcquisitionStartCopy.capacityTitle,
        ArchivePositioningCopy.firstUseTitle,
      );
      expect(
        AcquisitionStartCopy.capacityBody,
        ArchivePositioningCopy.firstUseBody,
      );
      expect(
        AcquisitionStartCopy.capacityBody.toLowerCase(),
        contains('save one real moment'),
      );
      expect(
        AcquisitionStartCopy.capacityBody.toLowerCase(),
        contains('see what returned'),
      );
      expect(AcquisitionStartCopy.capacityStartCta, 'Save first moment');
    });

    test('loop acquisition capacity variant aligned', () {
      final v = LoopAcquisitionCopy.capacityYes;
      expect(v.headline, ArchivePositioningCopy.wedgeHeadline);
      expect(v.subheadline.toLowerCase(), contains('agreeing'));
      expect(v.cta, 'Save yes moment');
    });

    test('capacity yes record handoff prompt is specific', () {
      expect(
        LoopModeCopy.capacityHandoffPrompt,
        'What are you about to agree to, and what makes it hard to pause?',
      );
      expect(
        AudienceWedge.sayingYesNoCapacity.firstPrompt,
        LoopModeCopy.capacityHandoffPrompt,
      );
    });

    test('beta success copy includes pay question', () {
      expect(BetaInviteCopy.betaSuccessChecklist.toLowerCase(), contains('real moments'));
      expect(BetaInviteCopy.betaSuccessChecklist.toLowerCase(), contains('return'));
      expect(BetaInviteCopy.betaSuccessChecklist.toLowerCase(), contains('returned'));
      expect(
        BetaInviteCopy.betaSuccessChecklist.toLowerCase(),
        contains('would pay to keep'),
      );
    });
  });

  group('Copy safety in wedge sharpening pack', () {
    test('no forbidden purchase CTAs in wedge dart copy', () {
      for (final cta in _forbiddenPurchaseCtas) {
        expect(wedgeDartSources, isNot(contains(cta)));
      }
    });

    test('no positive clinical claims in wedge dart copy', () {
      expect(_hasForbiddenClinicalClaim(wedgeDartSources), isFalse);
    });

    test('no forbidden score language', () {
      final lower = [onePager, scorecard, wedgeDartSources].join('\n').toLowerCase();
      for (final term in _forbiddenScoreTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no fake testimonials or invented user counts in docs', () {
      final lower = [onePager, scorecard].join('\n').toLowerCase();
      for (final phrase in _forbiddenHypePhrases) {
        expect(lower, isNot(contains(phrase)), reason: 'must not contain $phrase');
      }
    });

    test('public wedge copy does not use VoiceMemory as app name', () {
      expect(wedgeDartSources, isNot(contains('VoiceMemory')));
      expect(onePager, isNot(contains('VoiceMemory')));
      expect(scorecard, isNot(contains('VoiceMemory')));
    });
  });
}
