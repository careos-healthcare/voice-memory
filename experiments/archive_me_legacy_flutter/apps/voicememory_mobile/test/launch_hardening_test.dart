import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/subscriptions/data/default_subscription_repository.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';

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
  group('generated file guard', () {
    test('gitignore ignores test journal/prefs patterns', () {
      final gitignore = File('../../.gitignore').readAsStringSync();
      expect(gitignore, contains('apps/voicememory_mobile/*_journal.json'));
      expect(gitignore, contains('apps/voicememory_mobile/*_prefs.json'));
      expect(gitignore, contains('apps/voicememory_mobile/_journal.json'));
      expect(gitignore, contains('apps/voicememory_mobile/_prefs.json'));
    });

    test('validation script exists and is executable', () {
      final script = File(
        '../../scripts/validate-mobile-clean-working-tree.sh',
      );
      expect(script.existsSync(), isTrue);
      expect(script.readAsStringSync(), contains('*_journal.json'));
      expect(script.readAsStringSync(), contains('*_prefs.json'));
    });
  });

  group('launch validation docs', () {
    test('LAUNCH_VALIDATION.md contains focused test command', () {
      final doc = File('LAUNCH_VALIDATION.md').readAsStringSync();
      expect(doc, contains('flutter test'));
      expect(doc, contains('test/app_store_rc_polish_test.dart'));
      expect(doc, contains('test/launch_hardening_test.dart'));
      expect(doc, contains('validate-mobile-clean-working-tree.sh'));
    });

    test(
      'REVENUECAT_LAUNCH_BLOCKERS.md says purchases unavailable until setup',
      () {
        final doc = File('REVENUECAT_LAUNCH_BLOCKERS.md').readAsStringSync();
        expect(doc, contains('Purchases are not available'));
        expect(doc, contains('pro'));
        expect(doc, contains('| Paid launch ready | **No** |'));
      },
    );

    test('docs do not claim purchases are ready', () {
      for (final path in [
        'README.md',
        'docs/IOS_RELEASE_CHECKLIST.md',
        'docs/ANDROID_RELEASE_CHECKLIST.md',
      ]) {
        final lower = File(path).readAsStringSync().toLowerCase();
        expect(lower, isNot(contains('purchases are ready')));
        expect(lower, isNot(contains('billing is complete')));
        expect(lower, isNot(contains('paid launch is ready')));
      }
    });
  });

  group('route audit doc', () {
    test('includes key consumer routes and release-hidden verification', () {
      final doc = File('ROUTE_AUDIT.md').readAsStringSync();
      expect(doc, contains('/sample-archive'));
      expect(doc, contains('/help-reviewer-guide'));
      expect(doc, contains('/support-feedback'));
      expect(doc, contains('/pro-preview'));
      expect(doc, contains('/restore-purchases'));
      expect(doc, contains('/revenuecat-verify'));
      expect(doc.toLowerCase(), contains('release-hidden'));
    });
  });

  group('first two-session copy', () {
    test('0-entry archive home mentions sample archive calmly', () {
      final summary = ArchiveHomeSummaryEngine.build(entries: const []);
      expect(summary.body, ArchiveTabFourStateCopy.emptyBody);
      expect(summary.primaryCta, ArchiveTabFourStateCopy.recordMomentCta);
      expect(summary.footnoteLine, isNull);
      _expectNoBannedCopy([summary.body, summary.primaryCta!]);
    });

    test('1-entry next action explains why second moment matters', () {
      final summary = ArchiveHomeSummaryEngine.build(
        entries: [
          JournalEntry(
            id: 'e0',
            createdAt: DateTime(2026, 6, 12, 12),
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            durationSeconds: 30,
            localAudioPath: '/tmp/e0.m4a',
            reflection: const Reflection(
              mood: 'neutral',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: '',
              concreteObservation: 'Work pressure showed up.',
              repeatedSignal: '',
            ),
          ),
        ],
      );
      expect(summary.body, ArchiveTabFourStateCopy.oneBody);
      expect(
        RecordReturnProCopy.returnBody,
        VisibleArchiveProofCopy.firstSaveReturnTomorrowBody,
      );
      expect(
        RecordReturnProCopy.returnBody.toLowerCase(),
        contains('come back when'),
      );
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.firstSaveReturnTomorrowBody,
        VisibleArchiveProofCopy.secondMomentWhyLine,
        FirstThreeSessionCopy.session1ReturnTomorrow,
      ]);
    });

    test('single onboarding promise stays grounded in exact words', () {
      final page = OnboardingPages.pages.single;
      expect(page.body.toLowerCase(), contains('exact words'));
      expect(page.body.toLowerCase(), isNot(contains('personality')));
      _expectNoBannedCopy([page.title, page.body]);
    });

    test('updated docs use ArchiveMe not VoiceMemory in user-facing prose', () {
      for (final path in [
        'LAUNCH_VALIDATION.md',
        'REVENUECAT_LAUNCH_BLOCKERS.md',
        'ROUTE_AUDIT.md',
        'README.md',
      ]) {
        final doc = File(path).readAsStringSync();
        expect(doc, contains('ArchiveMe'));
        expect(doc, isNot(contains('VoiceMemory')));
      }
    });
  });

  group('billing entitlement merge', () {
    test('configured RevenueCat free beats stale cached Pro', () {
      const stalePro = SubscriptionState(
        tier: SubscriptionTier.pro,
        entitlementIds: ['pro'],
        billingConnected: true,
        origin: SubscriptionStateOrigin.cache,
      );
      const storeFree = SubscriptionState(
        tier: SubscriptionTier.free,
        entitlementIds: [],
        billingConnected: true,
        origin: SubscriptionStateOrigin.store,
        verification: SubscriptionVerification.verified,
      );

      final merged = DefaultSubscriptionRepository.mergeStates(
        server: stalePro,
        store: storeFree,
        storeAvailable: true,
      );

      expect(merged.isPro, isFalse);
    });

    test('store Pro still wins when configured', () {
      const storePro = SubscriptionState(
        tier: SubscriptionTier.pro,
        entitlementIds: ['pro'],
        billingConnected: true,
        origin: SubscriptionStateOrigin.store,
      );

      final merged = DefaultSubscriptionRepository.mergeStates(
        server: SubscriptionState.free(),
        store: storePro,
        storeAvailable: true,
      );

      expect(merged.isPro, isTrue);
    });

    test('unconfigured billing may use server cache', () {
      const cachedPro = SubscriptionState(
        tier: SubscriptionTier.pro,
        entitlementIds: ['pro'],
        billingConnected: true,
        origin: SubscriptionStateOrigin.cache,
      );

      final merged = DefaultSubscriptionRepository.mergeStates(
        server: cachedPro,
        store: SubscriptionState.free(),
        storeAvailable: false,
      );

      expect(merged.isPro, isTrue);
    });
  });
}
