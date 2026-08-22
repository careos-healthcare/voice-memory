import 'dart:io';

import 'package:archiveme_mobile/features/review/review_prompt_after_value.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/review/review_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/review_prompt/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

class _FakeReviewLauncher implements ReviewLauncher {
  int requests = 0;

  @override
  Future<bool> requestReview() async {
    requests++;
    return true;
  }
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    ReviewPromptAfterValue.resetSessionForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    ReviewPromptAfterValue.resetSessionForTest();
  });

  group('Copy guardrails', () {
    test('copy is exact', () {
      expect(
        ReviewPromptAfterValue.title,
        'Is ArchiveMe worth a quick rating?',
      );
      expect(
        ReviewPromptAfterValue.body,
        'If it helped you notice something useful, a rating would help '
        'others find it.',
      );
      expect(ReviewPromptAfterValue.ctaLabel, 'Rate ArchiveMe');
      expect(ReviewPromptAfterValue.dismissLabel, 'Not now');
    });

    test('no banned words, pressure language, or VoiceMemory', () {
      final copy = [
        ReviewPromptAfterValue.title,
        ReviewPromptAfterValue.body,
        ReviewPromptAfterValue.ctaLabel,
        ReviewPromptAfterValue.dismissLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'streak',
        'daily',
        'habit',
        'guilt',
        'missed',
        'must',
        'should',
        'task',
        'homework',
        'diagnose',
        'therapy',
        'treatment',
        'problem',
        'fix',
        'failure',
        'lazy',
        'weak',
        'voicememory',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'review prompt copy must not contain "$banned"',
        );
      }
    });
  });

  group('Trigger gate', () {
    test('no source before any value moment', () {
      expect(
        ReviewPromptAfterValue.sourceFor(entryCount: 5, hasWeeklyReview: false),
        isNull,
      );
      expect(
        ReviewPromptAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: false,
          alreadyAsked: false,
        ),
        isFalse,
      );
    });

    test('blocked before 2 entries, whatever the signals say', () {
      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'weekly_thread_review',
        useful: true,
      );
      ReviewPromptAfterValue.recordProRetentionYes();
      ReviewPromptAfterValue.recordReferralInviteCopied();
      for (final entryCount in const [0, 1]) {
        expect(
          ReviewPromptAfterValue.shouldShow(
            entryCount: entryCount,
            hasWeeklyReview: true,
            alreadyAsked: false,
          ),
          isFalse,
          reason: 'must not show at $entryCount entries',
        );
      }
    });

    test('a useful-yes becomes the trigger source', () {
      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'thread_return_evidence',
        useful: true,
      );
      expect(
        ReviewPromptAfterValue.sourceFor(entryCount: 2, hasWeeklyReview: false),
        'thread_return',
      );
      expect(
        ReviewPromptAfterValue.shouldShow(
          entryCount: 2,
          hasWeeklyReview: false,
          alreadyAsked: false,
        ),
        isTrue,
      );
    });

    test('weekly review triggers passively only at 3+ entries', () {
      expect(
        ReviewPromptAfterValue.sourceFor(entryCount: 2, hasWeeklyReview: true),
        isNull,
      );
      expect(
        ReviewPromptAfterValue.sourceFor(entryCount: 3, hasWeeklyReview: true),
        'weekly_review',
      );
    });

    test('Pro retention yes and invite copied are triggers on their own', () {
      ReviewPromptAfterValue.recordProRetentionYes();
      expect(
        ReviewPromptAfterValue.sourceFor(entryCount: 2, hasWeeklyReview: false),
        'pro_retention_yes',
      );
      ReviewPromptAfterValue.resetSessionForTest();
      ReviewPromptAfterValue.recordReferralInviteCopied();
      expect(
        ReviewPromptAfterValue.sourceFor(entryCount: 2, hasWeeklyReview: false),
        'referral_invite_copied',
      );
    });

    test('a Not quite response suppresses the prompt for the session', () {
      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'weekly_thread_review',
        useful: false,
      );
      // Even a later strong signal stays suppressed this session.
      ReviewPromptAfterValue.recordProRetentionYes();
      expect(
        ReviewPromptAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: true,
          alreadyAsked: false,
        ),
        isFalse,
      );
    });

    test('shown, dismissed, or persisted-asked hides it', () {
      ReviewPromptAfterValue.recordProRetentionYes();
      ReviewPromptAfterValue.shownThisSession = true;
      expect(
        ReviewPromptAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: true,
          alreadyAsked: false,
        ),
        isFalse,
      );
      ReviewPromptAfterValue.shownThisSession = false;
      ReviewPromptAfterValue.dismissedThisSession = true;
      expect(
        ReviewPromptAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: true,
          alreadyAsked: false,
        ),
        isFalse,
      );
      ReviewPromptAfterValue.dismissedThisSession = false;
      expect(
        ReviewPromptAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: true,
          alreadyAsked: true,
        ),
        isFalse,
      );
    });

    test('every resolvable source is on the stable whitelist', () {
      for (final cardType in const [
        'weekly_thread_review',
        'thread_return_evidence',
        'belief_distance',
        'archive_proof_counter',
      ]) {
        ReviewPromptAfterValue.resetSessionForTest();
        ReviewPromptAfterValue.recordValueFeedback(
          cardType: cardType,
          useful: true,
        );
        final source = ReviewPromptAfterValue.sourceFor(
          entryCount: 3,
          hasWeeklyReview: false,
        );
        expect(ReviewPromptAfterValue.stableSources, contains(source));
      }
    });
  });

  group('Asked-once store', () {
    test('defaults to not asked, persists after markAsked', () async {
      final prefs = _MemoryPrefs();
      final store = ReviewPromptStore(prefs: prefs);
      expect(await store.asked(), isFalse);
      await store.markAsked();
      expect(await store.asked(), isTrue);
      // A fresh store over the same prefs still reads asked.
      expect(await ReviewPromptStore(prefs: prefs).asked(), isTrue);
      // Only the boolean flag is stored — no timestamps or content.
      expect(prefs.maps[ReviewPromptStore.prefsKey], {'asked': true});
    });

    test('malformed stored data reads as not asked', () async {
      final prefs = _MemoryPrefs();
      prefs.maps[ReviewPromptStore.prefsKey] = {'asked': 'maybe'};
      expect(await ReviewPromptStore(prefs: prefs).asked(), isFalse);
    });
  });

  group('Prompt section and card', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      int entryCount = 3,
      bool hasWeeklyReview = false,
      ReviewPromptStore? store,
      ReviewLauncher? launcher,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReviewPromptSection(
                entryCount: entryCount,
                hasWeeklyReview: hasWeeklyReview,
                store: store ?? ReviewPromptStore(prefs: _MemoryPrefs()),
                launcher: launcher ?? _FakeReviewLauncher(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('does not show before any value moment', (tester) async {
      await pumpSection(tester, entryCount: 5);
      expect(find.byKey(const Key('review_prompt_card')), findsNothing);
    });

    testWidgets('does not show before 2 entries', (tester) async {
      ReviewPromptAfterValue.recordProRetentionYes();
      await pumpSection(tester, entryCount: 1);
      expect(find.byKey(const Key('review_prompt_card')), findsNothing);
    });

    testWidgets('appears after a useful yes with exact copy', (tester) async {
      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'weekly_thread_review',
        useful: true,
      );
      await pumpSection(tester, entryCount: 2);

      expect(find.byKey(const Key('review_prompt_card')), findsOneWidget);
      expect(find.text(ReviewPromptAfterValue.title), findsOneWidget);
      expect(find.text(ReviewPromptAfterValue.body), findsOneWidget);
      expect(find.text(ReviewPromptAfterValue.ctaLabel), findsOneWidget);
      expect(find.text(ReviewPromptAfterValue.dismissLabel), findsOneWidget);

      final seen = eventsNamed(ActivationFunnelAnalytics.reviewPromptSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'source': 'weekly_review',
        'card_type': 'weekly_review',
        'entry_count': 2,
      });
    });

    testWidgets('appears after a weekly review with enough entries', (
      tester,
    ) async {
      await pumpSection(tester, hasWeeklyReview: true);
      expect(find.byKey(const Key('review_prompt_card')), findsOneWidget);
    });

    testWidgets('does not appear after a Not quite', (tester) async {
      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'weekly_thread_review',
        useful: false,
      );
      await pumpSection(tester, entryCount: 5, hasWeeklyReview: true);
      expect(find.byKey(const Key('review_prompt_card')), findsNothing);
    });

    testWidgets('appears right after a useful-yes lands in the session', (
      tester,
    ) async {
      await pumpSection(tester);
      expect(find.byKey(const Key('review_prompt_card')), findsNothing);

      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'belief_distance',
        useful: true,
      );
      await tester.pump();
      expect(find.byKey(const Key('review_prompt_card')), findsOneWidget);
    });

    testWidgets('only once per session across section instances', (
      tester,
    ) async {
      ReviewPromptAfterValue.recordProRetentionYes();
      await pumpSection(tester);
      expect(find.byKey(const Key('review_prompt_card')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpSection(tester);
      expect(find.byKey(const Key('review_prompt_card')), findsNothing);
    });

    testWidgets('persisted asked flag prevents future prompts', (tester) async {
      final prefs = _MemoryPrefs();
      ReviewPromptAfterValue.recordProRetentionYes();
      await pumpSection(
        tester,
        store: ReviewPromptStore(prefs: prefs),
      );
      expect(find.byKey(const Key('review_prompt_card')), findsOneWidget);
      // Rendering persisted the flag without any tap.
      await tester.runAsync(
        () async =>
            expect(await ReviewPromptStore(prefs: prefs).asked(), isTrue),
      );

      // A new session with the same prefs never shows it again.
      ReviewPromptAfterValue.resetSessionForTest();
      ReviewPromptAfterValue.recordProRetentionYes();
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpSection(
        tester,
        entryCount: 5,
        store: ReviewPromptStore(prefs: prefs),
      );
      expect(find.byKey(const Key('review_prompt_card')), findsNothing);
    });

    testWidgets('CTA calls the review abstraction and logs the tap', (
      tester,
    ) async {
      final launcher = _FakeReviewLauncher();
      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'archive_proof_counter',
        useful: true,
      );
      await pumpSection(tester, entryCount: 4, launcher: launcher);

      await tester.tap(find.byKey(const Key('review_prompt_cta')));
      await tester.pump();

      expect(launcher.requests, 1);
      expect(find.byKey(const Key('review_prompt_card')), findsNothing);
      final tapped = eventsNamed(ActivationFunnelAnalytics.reviewPromptTapped);
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {
        'source': 'proof_counter',
        'card_type': 'proof_counter',
        'entry_count': 4,
      });
    });

    testWidgets('dismiss logs the event and just closes', (tester) async {
      ReviewPromptAfterValue.recordProRetentionYes();
      await pumpSection(tester);

      await tester.tap(find.byKey(const Key('review_prompt_dismiss')));
      await tester.pump();

      expect(find.byKey(const Key('review_prompt_card')), findsNothing);
      final dismissed = eventsNamed(
        ActivationFunnelAnalytics.reviewPromptDismissed,
      );
      expect(dismissed, hasLength(1));
      expect(dismissed.single.properties, {
        'source': 'pro_retention_yes',
        'card_type': 'pro_retention_yes',
        'entry_count': 3,
      });
      // No guilt, no follow-up — nothing else rendered in its place.
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('analytics payloads carry whitelisted keys only', (
      tester,
    ) async {
      ReviewPromptAfterValue.recordValueFeedback(
        cardType: 'thread_return_evidence',
        useful: true,
      );
      await pumpSection(tester);
      await tester.tap(find.byKey(const Key('review_prompt_cta')));
      await tester.pump();

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(e.properties.keys.toSet(), {
          'source',
          'card_type',
          'entry_count',
        }, reason: '${e.event} carries unexpected keys');
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        // No raw notes, snippets, source terms, URLs, or branding.
        expect(flat, isNot(contains('deadline')));
        expect(flat, isNot(contains('emails')));
        expect(flat, isNot(contains('https://')));
        expect(flat, isNot(contains('@')));
        expect(flat, isNot(contains('voicememory')));
        expect(
          ReviewPromptAfterValue.stableSources,
          contains(e.properties['source']),
        );
      }
    });

    testWidgets('the default launcher is a safe no-op', (tester) async {
      ReviewPromptAfterValue.recordProRetentionYes();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewPromptSection(
              entryCount: 3,
              hasWeeklyReview: false,
              store: ReviewPromptStore(prefs: _MemoryPrefs()),
              // No launcher injected — the const no-op default is used.
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('review_prompt_cta')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}