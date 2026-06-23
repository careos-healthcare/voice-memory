import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _supportUrl = 'https://careosapp.co.uk/archiveme-support';

const _expectedCaptions = [
  'Save a private moment',
  'See what repeats over time',
  'Review evidence, not guesses',
  'Know what to add next',
  'Watch themes you care about',
  'Try a sample archive',
  'Export only when you choose',
];

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
];

const _forbiddenPurchaseClaims = [
  'purchases are ready',
  'billing is complete',
  'revenuecat is live',
  'paid launch ready',
];

String _read(String path) => File(path).readAsStringSync();

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word.toLowerCase())),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('App Store submission pack docs', () {
    late String submissionPack;
    late String captionsDoc;
    late String walkthroughDoc;

    setUp(() {
      submissionPack = _read('APP_STORE_SUBMISSION_PACK.md');
      captionsDoc = _read('APP_STORE_SCREENSHOT_CAPTIONS.md');
      walkthroughDoc = _read('MANUAL_WALKTHROUGH_CHECKLIST.md');
    });

    test('submission pack exists with ArchiveMe identity', () {
      expect(submissionPack, contains('ArchiveMe'));
      expect(submissionPack, contains(_supportUrl));
      expect(submissionPack.toLowerCase(), contains('not complete'));
    });

    test('purchases described as unavailable until setup complete', () {
      expect(submissionPack.toLowerCase(), contains('unavailable'));
      expect(walkthroughDoc.toLowerCase(), contains('unavailable'));
      expect(captionsDoc.toLowerCase(), contains('not yet uploaded'));
      for (final doc in [submissionPack, captionsDoc, walkthroughDoc]) {
        final lower = doc.toLowerCase();
        for (final claim in _forbiddenPurchaseClaims) {
          expect(lower, isNot(contains(claim)));
        }
      }
      expect(submissionPack.toLowerCase(), contains('not live'));
      expect(submissionPack.toLowerCase(), contains('do not claim'));
    });

    test('reviewer path includes Type instead and Sample Archive', () {
      expect(submissionPack, contains('Type instead'));
      expect(submissionPack, contains('Sample Archive'));
      expect(submissionPack, contains('Help & reviewer guide'));
      expect(submissionPack, contains('Support & feedback'));
      expect(submissionPack, contains('Pro Preview'));
      expect(submissionPack.toLowerCase(), contains('purchases are not live'));
    });

    test('screenshot captions doc contains expected captions', () {
      for (final caption in _expectedCaptions) {
        expect(captionsDoc, contains(caption));
      }
      _expectNoBannedCopy(_expectedCaptions);
    });

    test('no Buy now or Subscribe now in submission docs', () {
      for (final doc in [captionsDoc, walkthroughDoc]) {
        expect(doc.toLowerCase(), isNot(contains('buy now')));
        expect(doc.toLowerCase(), isNot(contains('subscribe now')));
      }
      expect(submissionPack.toLowerCase(), isNot(contains('buy now')));
      expect(submissionPack.toLowerCase(), isNot(contains('subscribe now')));
    });

    test('no VoiceMemory in user-facing submission docs', () {
      for (final doc in [captionsDoc, walkthroughDoc]) {
        expect(doc, isNot(contains('VoiceMemory')));
        expect(doc.toLowerCase(), isNot(contains('voice memory')));
      }
      final packWithoutBundleLine = submissionPack
          .split('\n')
          .where((line) => !line.contains('com.voicememory.app'))
          .join('\n');
      expect(packWithoutBundleLine, isNot(contains('VoiceMemory')));
      expect(packWithoutBundleLine.toLowerCase(), isNot(contains('voice memory')));
    });

    test('submission docs avoid banned language in captions', () {
      _expectNoBannedCopy(_expectedCaptions);
      // Caption rules line may mention what to avoid; scan table captions only.
    });

    test('submission pack privacy uses appropriate disclaimers', () {
      expect(submissionPack.toLowerCase(), contains('is not therapy'));
      expect(submissionPack.toLowerCase(), contains('not conclusions'));
    });

    test('manual walkthrough includes required paths', () {
      expect(walkthroughDoc.toLowerCase(), contains('fresh install'));
      expect(walkthroughDoc, contains('Microphone denied'));
      expect(walkthroughDoc, contains('Type instead'));
      expect(walkthroughDoc, contains('Sample Archive'));
      expect(walkthroughDoc, contains('Support'));
      expect(walkthroughDoc, contains('Pro Preview'));
      expect(walkthroughDoc, contains('Restore purchases'));
      expect(walkthroughDoc.toLowerCase(), contains('offline'));
      expect(walkthroughDoc.toLowerCase(), contains('privacy'));
    });

    test('docs do not claim submission or RevenueCat is complete', () {
      expect(
        submissionPack.toLowerCase(),
        isNot(contains('submission is complete')),
      );
      expect(
        submissionPack.toLowerCase(),
        isNot(matches(RegExp(r'submission complete:\s*yes', caseSensitive: false))),
      );
      expect(walkthroughDoc, contains('Submission complete:** No'));
    });
  });
}
