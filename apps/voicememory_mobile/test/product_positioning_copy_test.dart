import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/landing_continuity/landing_app_continuity_copy.dart';
import 'package:voicememory_mobile/features/monetization/domain/contextual_paywall_policy.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/v1_interface/progressive_evidence_state_copy.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/archive_me_v1_product_contract.dart';
import 'package:voicememory_mobile/product/auditable_change_positioning.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/product/core_product_vision.dart';

/// The forbidden-headline scan runs against these slots and nothing else.
///
/// A slot is one string a reader meets as primary positioning: a headline, a
/// category line, a subtitle, or the opening paragraph of a listing. Body copy
/// is deliberately out of scope, so a factual secondary sentence such as
/// "ArchiveMe uses AI for transcription" stays legal — see the false-positive
/// test at the bottom of this file.
Map<String, String> _dartPrimarySlots() => {
  'positioning source — category': AuditableChangePositioning.category,
  'positioning source — promise': AuditableChangePositioning.primaryPromise,
  'positioning source — full sentence': AuditableChangePositioning.full,
  'first-launch value proposition': CoreProductVision.valueProposition,
  'App Store subtitle constant': CoreProductVision.appStoreSubtitle,
  'Play short description constant':
      CoreProductVision.playStoreShortDescription,
  'onboarding title': OnboardingPages.pages.first.title,
  'onboarding body': OnboardingPages.pages.first.body,
  'Record first-run title': VisibleArchiveProofCopy.firstRunRecordTitle,
  'Record first-run body': VisibleArchiveProofCopy.firstRunRecordBody,
  'Record empty-state body': ProgressiveEvidenceStateCopy.zeroBody,
  'Changes lead': ConsumerUiCopy.changesScreenLead,
  'umbrella headline': ConsumerUiCopy.archivePositioningHeadline,
  'umbrella subhead': ConsumerUiCopy.archivePositioningSubhead,
  'paywall headline': PaywallAlignmentCopy.headline,
  'paywall positioning line': ContextualPaywallCopy.positioning,
  'paywall category line': PaywallAlignmentCopy.positioningCategory,
  'marketing hero': LandingAppContinuityCopy.hero,
  'marketing subheadline': LandingAppContinuityCopy.subheadline,
  'V1 contract category': ArchiveMeV1ProductContract.category,
  'V1 contract promise': ArchiveMeV1ProductContract.promise,
  'V1 contract positioning': ArchiveMeV1ProductContract.positioning,
};

/// Markdown files paired with the headings whose first paragraph is a primary
/// slot. Naming the headings — rather than scanning the file — is what keeps a
/// listing free to state secondary facts about AI further down the page.
const _markdownPrimarySlots = <String, List<String>>{
  'docs/APP_STORE_COPY.md': [
    'Category',
    'Subtitle',
    'Short description',
    'Long description',
  ],
  'docs/PLAY_STORE_COPY.md': [
    'Category',
    'Short description (≤80 characters)',
    'Full description',
  ],
  '../../docs/V1_REVIEWER_INSTRUCTIONS.md': [
    'ArchiveMe focused V1 reviewer instructions',
  ],
};

/// Plain-text store slots, paired with whether the whole file is the slot.
const _textPrimarySlots = <String, bool>{
  'ios/fastlane/metadata/en-US/subtitle.txt': true,
  'ios/fastlane/metadata/en-US/promotional_text.txt': true,
  'ios/fastlane/metadata/en-US/description.txt': false,
};

/// The first paragraph under [heading], with markdown emphasis removed.
String _paragraphUnder(String source, String heading) {
  final lines = source.split('\n');
  var index = lines.indexWhere(
    (line) =>
        line.startsWith('#') && line.replaceAll('#', '').trim() == heading,
  );
  expect(index, greaterThanOrEqualTo(0), reason: 'missing heading: $heading');
  index += 1;
  final paragraph = <String>[];
  for (; index < lines.length; index++) {
    final line = lines[index];
    if (line.startsWith('#')) break;
    if (line.trim().isEmpty) {
      if (paragraph.isNotEmpty) break;
      continue;
    }
    paragraph.add(line.trim());
  }
  return paragraph.join(' ').replaceAll('*', '').replaceAll('`', '');
}

String _firstParagraph(String source) {
  final paragraph = <String>[];
  for (final line in source.split('\n')) {
    if (line.trim().isEmpty) {
      if (paragraph.isNotEmpty) break;
      continue;
    }
    paragraph.add(line.trim());
  }
  return paragraph.join(' ');
}

void main() {
  group('no forbidden headline leads any primary positioning slot', () {
    for (final entry in _dartPrimarySlots().entries) {
      test(entry.key, () {
        expect(
          AuditableChangePositioning.forbiddenHeadlinesIn(entry.value),
          isEmpty,
          reason:
              '"${entry.value}" leads with positioning that V1 forbids. '
              'Lead with AuditableChangePositioning instead.',
        );
      });
    }

    for (final entry in _markdownPrimarySlots.entries) {
      test(entry.key, () {
        final source = File(entry.key).readAsStringSync();
        for (final heading in entry.value) {
          final slot = _paragraphUnder(source, heading);
          expect(
            AuditableChangePositioning.forbiddenHeadlinesIn(slot),
            isEmpty,
            reason:
                '${entry.key} → "$heading" leads with forbidden '
                'positioning: "$slot"',
          );
        }
      });
    }

    for (final entry in _textPrimarySlots.entries) {
      test(entry.key, () {
        final source = File(entry.key).readAsStringSync();
        final slot = entry.value ? source.trim() : _firstParagraph(source);
        expect(
          AuditableChangePositioning.forbiddenHeadlinesIn(slot),
          isEmpty,
          reason: '${entry.key} leads with forbidden positioning: "$slot"',
        );
      });
    }
  });

  group('the positioning hierarchy is wired, not restated', () {
    test('every product surface resolves to the canonical source', () {
      expect(
        CoreProductVision.valueProposition,
        AuditableChangePositioning.full,
      );
      expect(
        OnboardingPages.pages.first.title,
        AuditableChangePositioning.primaryPromise,
      );
      expect(
        OnboardingPages.pages.first.body,
        startsWith(AuditableChangePositioning.full),
      );
      expect(
        VisibleArchiveProofCopy.firstRunRecordTitle,
        AuditableChangePositioning.primaryPromise,
      );
      expect(
        VisibleArchiveProofCopy.firstRunRecordBody,
        AuditableChangePositioning.full,
      );
      expect(
        ConsumerUiCopy.archivePositioningHeadline,
        AuditableChangePositioning.primaryPromise,
      );
      expect(
        ConsumerUiCopy.archivePositioningSubhead,
        AuditableChangePositioning.full,
      );
      expect(
        ContextualPaywallCopy.positioning,
        AuditableChangePositioning.primaryPromise,
      );
      expect(
        PaywallAlignmentCopy.positioningCategory,
        AuditableChangePositioning.category,
      );
      expect(
        LandingAppContinuityCopy.hero,
        AuditableChangePositioning.primaryPromise,
      );
      expect(
        ArchiveMeV1ProductContract.promise,
        AuditableChangePositioning.primaryPromise,
      );
      expect(
        ArchiveMeV1ProductContract.positioning,
        AuditableChangePositioning.full,
      );
    });

    test('the empty Record and Changes states echo the promise', () {
      expect(ProgressiveEvidenceStateCopy.zeroBody, contains('what repeated'));
      expect(ProgressiveEvidenceStateCopy.zeroBody, contains('what changed'));
      expect(ConsumerUiCopy.changesScreenLead, contains('See what repeated.'));
      expect(ConsumerUiCopy.changesScreenLead, contains('See what changed.'));
    });

    test('store listing slots carry the canonical strings verbatim', () {
      final appStore = File('docs/APP_STORE_COPY.md').readAsStringSync();
      final play = File('docs/PLAY_STORE_COPY.md').readAsStringSync();

      expect(
        _paragraphUnder(appStore, 'Category'),
        AuditableChangePositioning.category,
      );
      expect(
        _paragraphUnder(appStore, 'Subtitle'),
        AuditableChangePositioning.appStoreSubtitle,
      );
      expect(
        _paragraphUnder(appStore, 'Short description'),
        AuditableChangePositioning.primaryPromise,
      );
      expect(
        _paragraphUnder(appStore, 'Long description'),
        AuditableChangePositioning.full,
      );
      expect(
        _paragraphUnder(play, 'Category'),
        AuditableChangePositioning.category,
      );
      expect(
        _paragraphUnder(play, 'Short description (≤80 characters)'),
        AuditableChangePositioning.playStoreShortDescription,
      );
      expect(
        _paragraphUnder(play, 'Full description'),
        AuditableChangePositioning.full,
      );
      expect(
        File(
          'ios/fastlane/metadata/en-US/subtitle.txt',
        ).readAsStringSync().trim(),
        AuditableChangePositioning.appStoreSubtitle,
      );
      expect(
        File(
          'ios/fastlane/metadata/en-US/promotional_text.txt',
        ).readAsStringSync().trim(),
        AuditableChangePositioning.full,
      );
      expect(
        _firstParagraph(
          File(
            'ios/fastlane/metadata/en-US/description.txt',
          ).readAsStringSync(),
        ),
        AuditableChangePositioning.full,
      );
      expect(
        AuditableChangePositioning.appStoreSubtitle.length,
        lessThanOrEqualTo(30),
      );
      expect(
        AuditableChangePositioning.playStoreShortDescription.length,
        lessThanOrEqualTo(80),
      );
    });

    test('the marketing source mirrors the Dart strings byte for byte', () {
      final marketing = File(
        '../../lib/product/archive-positioning.ts',
      ).readAsStringSync();
      expect(marketing, contains('"${AuditableChangePositioning.category}"'));
      expect(
        marketing,
        contains('"${AuditableChangePositioning.primaryPromise}"'),
      );
      expect(marketing, contains('"${AuditableChangePositioning.full}"'));
    });

    test('the reviewer notes and product contract state the positioning', () {
      for (final path in [
        'docs/APP_REVIEW_NOTES.md',
        '../../docs/V1_REVIEWER_INSTRUCTIONS.md',
        '../../docs/current/PRODUCT_CONTRACT.md',
      ]) {
        // Markdown wraps prose, so compare against unwrapped, unemphasised text.
        final source = File(path)
            .readAsStringSync()
            .replaceAll(RegExp(r'[*`]'), '')
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(
          source,
          contains(AuditableChangePositioning.primaryPromise),
          reason: '$path must state the promise verbatim',
        );
        expect(
          source.toLowerCase(),
          contains('auditable personal change'),
          reason: '$path must name the category',
        );
      }
    });
  });

  group('the guard is precise', () {
    test('a forbidden headline in a primary slot is caught', () {
      for (final headline in [
        'The AI journal that remembers you.',
        'Your private voice journal.',
        'Ask your history anything.',
        'The life operating system for your mind.',
        'Your AI companion that knows you.',
        'Personalised insights from your past.',
        'Uncover the hidden truth about your personality type.',
        'Therapy in your pocket.',
        'Your memory assistant.',
        'Turn your voice into one unified life story.',
      ]) {
        expect(
          AuditableChangePositioning.forbiddenHeadlinesIn(headline),
          isNotEmpty,
          reason: 'guard missed forbidden primary headline: "$headline"',
        );
      }
    });

    test('a factual secondary mention of AI is not flagged', () {
      for (final sentence in [
        'ArchiveMe uses AI for transcription and for drafting each '
            'observation.',
        'AI drafts the observation; the exact saved words and dates prove it.',
        'Transcription and analysis run on remote AI models when you use them.',
        'ArchiveMe is not therapy, medical advice, or a diagnosis.',
        'An AI model reads only the moments you saved.',
      ]) {
        expect(
          AuditableChangePositioning.forbiddenHeadlinesIn(sentence),
          isEmpty,
          reason: 'guard falsely flagged a secondary AI fact: "$sentence"',
        );
      }
    });

    test('listing body copy may state AI facts the slot scan never sees', () {
      final appStore = File('docs/APP_STORE_COPY.md').readAsStringSync();
      final description = File(
        'ios/fastlane/metadata/en-US/description.txt',
      ).readAsStringSync();

      // Both documents deliberately contain sentences that a naive whole-file
      // scan would reject, and both still pass the slot scan above.
      expect(appStore, contains('ArchiveMe uses AI for transcription'));
      expect(appStore, contains('Therapy, diagnosis'));
      expect(
        description,
        contains('not therapy, medical advice, or a diagnosis'),
      );
      expect(
        AuditableChangePositioning.forbiddenHeadlinesIn(
          _paragraphUnder(appStore, 'Long description'),
        ),
        isEmpty,
      );
      expect(
        AuditableChangePositioning.forbiddenHeadlinesIn(
          _firstParagraph(description),
        ),
        isEmpty,
      );
    });
  });
}
