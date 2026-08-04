import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _packPath = 'APP_STORE_SUBMISSION_PACK.md';
const _reviewNotesPath = 'docs/APP_REVIEW_NOTES.md';
const _storeCopyPath = 'docs/APP_STORE_COPY.md';
const _iosChecklistPath = 'docs/IOS_RELEASE_CHECKLIST.md';

const _supportUrl = 'https://careosapp.co.uk/archiveme-support';
const _bundleId = 'com.voicememory.mobile';
const _legacyBundleId = 'com.voicememory.app';

const _forbiddenPurchaseCtas = ['Buy now', 'Subscribe now', 'Pro is active'];

void main() {
  late String pack;
  late String reviewNotes;
  late String storeCopy;
  late String iosChecklist;

  setUpAll(() {
    pack = File(_packPath).readAsStringSync();
    reviewNotes = File(_reviewNotesPath).readAsStringSync();
    storeCopy = File(_storeCopyPath).readAsStringSync();
    iosChecklist = File(_iosChecklistPath).readAsStringSync();
  });

  group('APP_STORE_SUBMISSION_PACK.md', () {
    test('exists and states core release identity', () {
      expect(File(_packPath).existsSync(), isTrue);
      expect(pack, contains('ArchiveMe'));
      expect(pack, contains(_bundleId));
      expect(pack, contains(_supportUrl));
      expect(pack, contains('ios/Runner.xcworkspace'));
      expect(pack, contains('0.2.0'));
      expect(pack, contains('49'));
    });

    test('documents reviewer and support paths', () {
      expect(pack, contains('Sample Archive'));
      expect(pack, contains('Support & feedback'));
      expect(pack, contains('Subscription'));
      expect(pack, contains('Restore purchases'));
      expect(pack, contains('/sample-archive'));
      expect(pack, contains('/support-feedback'));
      expect(pack, contains('/subscription'));
    });

    test('states conditional store pricing without claiming sandbox proof', () {
      expect(pack.toLowerCase(), contains('revenuecat'));
      expect(pack, contains('monthly and annual'));
      expect(pack, contains('no fabricated price'));
      expect(pack, contains('Do not claim purchases are live'));
    });

    test('does not overclaim purchases or use forbidden CTAs', () {
      for (final cta in _forbiddenPurchaseCtas) {
        expect(pack, isNot(contains(cta)));
      }
      expect(pack, isNot(contains(_legacyBundleId)));
    });

    test('includes manual TestFlight checklist and validation commands', () {
      expect(pack, contains('TestFlight internal test checklist'));
      expect(pack, contains('flutter build ios --release --no-codesign'));
      expect(pack, contains('placeholder app icon'));
    });
  });

  group('Reviewer docs alignment', () {
    test('APP_STORE_COPY uses ArchiveMe not VoiceMemory as public name', () {
      expect(storeCopy, contains('ArchiveMe'));
      expect(storeCopy, isNot(contains('VoiceMemory')));
    });

    test(
      'APP_REVIEW_NOTES contains reviewer path, review code, and support URL',
      () {
        expect(reviewNotes, contains('ArchiveMe'));
        expect(reviewNotes, contains(_bundleId));
        expect(reviewNotes, contains(_supportUrl));
        expect(reviewNotes, contains('ARCHIVEME-REVIEW-2026'));
        expect(reviewNotes, contains('App Review Access'));
        expect(reviewNotes, contains('Sample Archive'));
        expect(reviewNotes, contains('Support'));
      },
    );

    test('IOS_RELEASE_CHECKLIST contains bundle ID and workspace', () {
      expect(iosChecklist, contains(_bundleId));
      expect(iosChecklist, contains('ios/Runner.xcworkspace'));
      expect(iosChecklist, isNot(contains('Buy now')));
    });
  });
}
