import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/submission/app_store_submission_copy.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

const _fakePurchaseClaims = [
  'purchase works',
  'subscription active',
  'subscribe now',
  'payment successful',
  'billing is live',
  'pro unlock works',
];

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
  }
}

void main() {
  group('App Store submission copy', () {
    test('uses ArchiveMe branding, not VoiceMemory', () {
      final visible = [
        ...AppStoreSubmissionCopy.screenshotCaptions,
        ...AppStoreSubmissionCopy.reviewerNotes,
        ...AppStoreSubmissionCopy.suggestedReviewPathBullets,
        AppStoreSubmissionCopy.privacyExplanationBody,
        AppStoreSubmissionCopy.buildReviewerNotesBlock(),
        AppStoreSubmissionCopy.buildDemoPathChecklist(),
      ];
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(
        AppStoreSubmissionCopy.reviewerNoteTypeInstead,
        contains('ArchiveMe'),
      );
    });

    test('screenshot captions avoid banned language', () {
      _expectNoBannedCopy(AppStoreSubmissionCopy.screenshotCaptions);
      expect(AppStoreSubmissionCopy.screenshotCaptions, hasLength(6));
    });

    test('reviewer notes cover Type instead, Sample Archive, and privacy', () {
      final notes = AppStoreSubmissionCopy.reviewerNotes;
      _expectNoBannedCopy(notes);
      expect(
        notes,
        contains(AppStoreSubmissionCopy.reviewerNoteTypeInstead),
      );
      expect(notes, contains(AppStoreSubmissionCopy.reviewerNoteSampleArchive));
      expect(
        notes,
        contains(AppStoreSubmissionCopy.reviewerNotePrivacyControls),
      );
      expect(
        notes,
        contains(AppStoreSubmissionCopy.reviewerNoteShareSafeProof),
      );
      expect(
        AppStoreSubmissionCopy.reviewerNoteTypeInstead,
        contains(VisibleArchiveProofCopy.typeInsteadCta),
      );
      expect(
        AppStoreSubmissionCopy.reviewerNoteSampleArchive.toLowerCase(),
        contains('example data'),
      );
    });

    test('reviewer notes block includes support URL and no fake purchase claims', () {
      final block = AppStoreSubmissionCopy.buildReviewerNotesBlock();
      expect(block, contains(AppConfig.supportUrl));
      expect(block, contains('archiveme-support'));
      expect(
        block,
        contains(AppStoreSubmissionCopy.reviewerNoteRevenueCatPaused),
      );
      for (final claim in _fakePurchaseClaims) {
        expect(block.toLowerCase(), isNot(contains(claim)));
      }
    });

    test('demo path checklist references sample-safe paths', () {
      final checklist = AppStoreSubmissionCopy.buildDemoPathChecklist();
      expect(checklist, contains(AppStoreSubmissionCopy.demoPathChecklistTitle));
      expect(
        checklist,
        contains(AppStoreSubmissionCopy.demoPathChecklistOpenSampleArchive),
      );
      expect(
        checklist,
        contains(AppStoreSubmissionCopy.demoPathChecklistCopyDemoSummary),
      );
      _expectNoBannedCopy(AppStoreSubmissionCopy.demoPathChecklist);
    });

    test('privacy explanation stays share-safe and local-first', () {
      final block = AppStoreSubmissionCopy.buildPrivacyExplanationBlock();
      expect(block, contains(AppStoreSubmissionCopy.privacyExplanationTitle));
      expect(block, contains('raw private entries'));
      expect(block.toLowerCase(), isNot(contains('voicememory')));
      _expectNoBannedCopy([AppStoreSubmissionCopy.privacyExplanationBody]);
    });

    test('build number remains 0.2.0+46', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: ${AppStoreSubmissionCopy.expectedVersionLine}'));
      expect(AppStoreSubmissionCopy.expectedVersion, '0.2.0');
      expect(AppStoreSubmissionCopy.expectedBuildNumber, 43);
    });

    test('support URL matches app config', () {
      expect(AppStoreSubmissionCopy.supportUrl, AppConfig.supportUrl);
      expect(AppStoreSubmissionCopy.supportUrl, startsWith('https://'));
    });
  });
}
