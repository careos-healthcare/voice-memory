import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/pro_retention_check.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/referral/invite_attribution.dart';
import 'package:voicememory_mobile/features/referral/referral_invite_after_value.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/value_accuracy_feedback_row.dart';
import 'package:voicememory_mobile/widgets/referral/referral_invite_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/referral_invite/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

PressureCheckInRecord _checkIn({
  required String id,
  required int daysAgo,
  String optionId = 'could_not_stop',
  List<String> contextIds = const ['work'],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// A connected work thread — weekly review, thread evidence, and a
/// connected proof counter all exist.
List<PressureCheckInRecord> _valueRecords() => [
  _checkIn(id: 'a', daysAgo: 6),
  _checkIn(id: 'b', daysAgo: 3, fear: 'The deadline slipping'),
  _checkIn(id: 'c', daysAgo: 0, fear: 'Late emails piling up'),
];

/// Three stale, unconnected entries — no review, no thread, no proof.
List<PressureCheckInRecord> _noValueRecords() => [
  _checkIn(id: 's0', daysAgo: 20, optionId: 'could_not_stop', contextIds: []),
  _checkIn(id: 's1', daysAgo: 15, optionId: 'guilty_resting', contextIds: []),
  _checkIn(
    id: 's2',
    daysAgo: 10,
    optionId: 'had_to_prove_enough',
    contextIds: [],
  ),
];

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
    ReferralInviteAfterValue.resetSessionForTest();
    ProRetentionCheck.resetSessionForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    ReferralInviteAfterValue.resetSessionForTest();
    ProRetentionCheck.resetSessionForTest();
  });

  group('Copy guardrails', () {
    test('copy is exact', () {
      expect(
        ReferralInviteAfterValue.title,
        'Know someone who might use this?',
      );
      expect(
        ReferralInviteAfterValue.body,
        'You can invite them without sharing anything from your archive.',
      );
      expect(ReferralInviteAfterValue.ctaLabel, 'Copy invite');
      expect(ReferralInviteAfterValue.dismissLabel, 'Not now');
      expect(
        ReferralInviteAfterValue.inviteText,
        'I\u2019m testing ArchiveMe \u2014 it helps you record one small '
        'thing and notice what keeps returning, fading, or changing over '
        'time. It does not share your archive. Want to try it?',
      );
    });

    test('source-specific invite variants are exact', () {
      expect(
        ReferralInviteAfterValue.weeklyReviewInviteText,
        'I\u2019m testing ArchiveMe. It helped me notice what returned, '
        'faded, or changed this week \u2014 without sharing my archive. '
        'Want to try it?',
      );
      expect(
        ReferralInviteAfterValue.threadReturnInviteText,
        'I\u2019m testing ArchiveMe. It helps you notice when the same '
        'thread keeps coming back \u2014 without sharing your archive. '
        'Want to try it?',
      );
      expect(
        ReferralInviteAfterValue.beliefDistanceInviteText,
        'I\u2019m testing ArchiveMe. It helps you notice belief-like '
        'phrases that keep showing up \u2014 without sharing your archive. '
        'Want to try it?',
      );
      expect(
        ReferralInviteAfterValue.proofCounterInviteText,
        'I\u2019m testing ArchiveMe. It helps you see when separate '
        'recordings start connecting \u2014 without sharing your archive. '
        'Want to try it?',
      );
      expect(
        ReferralInviteAfterValue.proRetentionInviteText,
        'I\u2019m testing ArchiveMe. It helps keep an archive of what '
        'returns, fades, and changes over time \u2014 without sharing '
        'anything private. Want to try it?',
      );
    });

    test(
      'invite text resolves by stable source id with a default fallback',
      () {
        expect(
          ReferralInviteAfterValue.inviteTextFor('weekly_review'),
          ReferralInviteAfterValue.weeklyReviewInviteText,
        );
        expect(
          ReferralInviteAfterValue.inviteTextFor('thread_return'),
          ReferralInviteAfterValue.threadReturnInviteText,
        );
        expect(
          ReferralInviteAfterValue.inviteTextFor('belief_distance'),
          ReferralInviteAfterValue.beliefDistanceInviteText,
        );
        expect(
          ReferralInviteAfterValue.inviteTextFor('proof_counter'),
          ReferralInviteAfterValue.proofCounterInviteText,
        );
        expect(
          ReferralInviteAfterValue.inviteTextFor('pro_retention_yes'),
          ReferralInviteAfterValue.proRetentionInviteText,
        );
        // Unknown or empty ids fall back to the default invite.
        expect(
          ReferralInviteAfterValue.inviteTextFor('something_else'),
          ReferralInviteAfterValue.inviteText,
        );
        expect(
          ReferralInviteAfterValue.inviteTextFor(''),
          ReferralInviteAfterValue.inviteText,
        );
      },
    );

    test('proof lines are exact, by source', () {
      expect(
        ReferralInviteAfterValue.defaultProofLine,
        'ArchiveMe has started showing value.',
      );
      expect(
        ReferralInviteAfterValue.weeklyReviewProofLine,
        'Your weekly review showed what returned, faded, or changed.',
      );
      expect(
        ReferralInviteAfterValue.threadReturnProofLine,
        'ArchiveMe noticed a thread coming back.',
      );
      expect(
        ReferralInviteAfterValue.beliefDistanceProofLine,
        'ArchiveMe noticed a phrase pattern showing up again.',
      );
      expect(
        ReferralInviteAfterValue.proofCounterProofLine,
        'Your archive started connecting recordings.',
      );
      expect(
        ReferralInviteAfterValue.proRetentionProofLine,
        'Pro helped keep the archive connected over time.',
      );
    });

    test('proof line resolves by stable source id with a default fallback', () {
      expect(
        ReferralInviteAfterValue.proofLineFor('weekly_review'),
        ReferralInviteAfterValue.weeklyReviewProofLine,
      );
      expect(
        ReferralInviteAfterValue.proofLineFor('thread_return'),
        ReferralInviteAfterValue.threadReturnProofLine,
      );
      expect(
        ReferralInviteAfterValue.proofLineFor('belief_distance'),
        ReferralInviteAfterValue.beliefDistanceProofLine,
      );
      expect(
        ReferralInviteAfterValue.proofLineFor('proof_counter'),
        ReferralInviteAfterValue.proofCounterProofLine,
      );
      expect(
        ReferralInviteAfterValue.proofLineFor('pro_retention_yes'),
        ReferralInviteAfterValue.proRetentionProofLine,
      );
      // Unknown or empty ids fall back to the default line.
      expect(
        ReferralInviteAfterValue.proofLineFor('something_else'),
        ReferralInviteAfterValue.defaultProofLine,
      );
      expect(
        ReferralInviteAfterValue.proofLineFor(''),
        ReferralInviteAfterValue.defaultProofLine,
      );
    });

    test(
      'no invite variant contains private content, counts, or raw terms',
      () {
        const variants = [
          ReferralInviteAfterValue.inviteText,
          ReferralInviteAfterValue.weeklyReviewInviteText,
          ReferralInviteAfterValue.threadReturnInviteText,
          ReferralInviteAfterValue.beliefDistanceInviteText,
          ReferralInviteAfterValue.proofCounterInviteText,
          ReferralInviteAfterValue.proRetentionInviteText,
          // Proof lines are clipboard-adjacent copy — same sweep applies.
          ReferralInviteAfterValue.defaultProofLine,
          ReferralInviteAfterValue.weeklyReviewProofLine,
          ReferralInviteAfterValue.threadReturnProofLine,
          ReferralInviteAfterValue.beliefDistanceProofLine,
          ReferralInviteAfterValue.proofCounterProofLine,
          ReferralInviteAfterValue.proRetentionProofLine,
        ];
        for (final invite in variants) {
          // No counts of any kind — numbers could leak archive state.
          expect(invite, isNot(matches(RegExp(r'[0-9]'))));
          // Compile-time constants: nothing dynamic can enter them.
          // Sanity-check no note-like or source-term content from fixtures.
          for (final fragment in const [
            'deadline',
            'emails',
            'work',
            'could_not_stop',
            'guilty_resting',
          ]) {
            expect(
              invite.toLowerCase(),
              isNot(contains(fragment)),
              reason: 'invite variant must not contain "$fragment"',
            );
          }
        }
      },
    );

    test('no banned words or VoiceMemory in any referral copy', () {
      final copy = [
        ReferralInviteAfterValue.title,
        ReferralInviteAfterValue.body,
        ReferralInviteAfterValue.ctaLabel,
        ReferralInviteAfterValue.dismissLabel,
        ReferralInviteAfterValue.copiedConfirmation,
        ReferralInviteAfterValue.inviteText,
        ReferralInviteAfterValue.weeklyReviewInviteText,
        ReferralInviteAfterValue.threadReturnInviteText,
        ReferralInviteAfterValue.beliefDistanceInviteText,
        ReferralInviteAfterValue.proofCounterInviteText,
        ReferralInviteAfterValue.proRetentionInviteText,
        ReferralInviteAfterValue.defaultProofLine,
        ReferralInviteAfterValue.weeklyReviewProofLine,
        ReferralInviteAfterValue.threadReturnProofLine,
        ReferralInviteAfterValue.beliefDistanceProofLine,
        ReferralInviteAfterValue.proofCounterProofLine,
        ReferralInviteAfterValue.proRetentionProofLine,
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
          reason: 'referral copy must not contain "$banned"',
        );
      }
    });
  });

  group('Invite attribution link', () {
    test(
      'link uses the single config URL with fixed ref and stable source',
      () {
        expect(
          ReferralInviteAfterValue.inviteBaseUrl,
          'https://archiveme.app/invite',
        );
        expect(ReferralInviteAfterValue.inviteRef, 'archive_invite');
        for (final source in const [
          'weekly_review',
          'thread_return',
          'belief_distance',
          'proof_counter',
          'pro_retention_yes',
        ]) {
          expect(
            ReferralInviteAfterValue.inviteLinkFor(source),
            'https://archiveme.app/invite?ref=archive_invite&source=$source',
          );
        }
      },
    );

    test('unknown source falls back to default in the link', () {
      for (final source in const ['', 'something_else', 'user@email.com']) {
        expect(
          ReferralInviteAfterValue.inviteLinkFor(source),
          'https://archiveme.app/invite?ref=archive_invite&source=default',
        );
      }
    });

    test('copied text is the invite variant plus the link, nothing else', () {
      expect(
        ReferralInviteAfterValue.copiedInviteTextFor('weekly_review'),
        '${ReferralInviteAfterValue.weeklyReviewInviteText}\n'
        'https://archiveme.app/invite?ref=archive_invite&source=weekly_review',
      );
      expect(
        ReferralInviteAfterValue.copiedInviteTextFor('unknown'),
        '${ReferralInviteAfterValue.inviteText}\n'
        'https://archiveme.app/invite?ref=archive_invite&source=default',
      );
    });

    test(
      'link carries no user id, email, count, timestamp, or private data',
      () {
        for (final source in const [
          'weekly_review',
          'thread_return',
          'belief_distance',
          'proof_counter',
          'pro_retention_yes',
          'anything_else',
        ]) {
          final link = ReferralInviteAfterValue.inviteLinkFor(source);
          final uri = Uri.parse(link);
          // Exactly two query parameters — nothing else can ride along.
          expect(uri.queryParameters.keys.toSet(), {'ref', 'source'});
          expect(uri.queryParameters['ref'], 'archive_invite');
          expect(
            ReferralInviteAfterValue.stableSources
                .union(const {'default'})
                .contains(uri.queryParameters['source']),
            isTrue,
          );
          // No digits (counts/timestamps/ids) and no email shapes.
          expect(link, isNot(matches(RegExp(r'[0-9]'))));
          expect(link, isNot(contains('@')));
          for (final fragment in const ['deadline', 'emails', 'work']) {
            expect(link.toLowerCase(), isNot(contains(fragment)));
          }
        }
      },
    );
  });

  group('Invite attribution deep link', () {
    test('valid invite link parses ref and source', () {
      final attribution = InviteAttributionLink.parse(
        Uri.parse(
          'https://archiveme.app/invite'
          '?ref=archive_invite&source=weekly_review',
        ),
      );
      expect(attribution, isNotNull);
      expect(attribution!.ref, 'archive_invite');
      expect(attribution.source, 'weekly_review');
    });

    test('invalid source falls back safely to default', () {
      final attribution = InviteAttributionLink.parse(
        Uri.parse(
          'https://archiveme.app/invite'
          '?ref=archive_invite&source=user%40email.com',
        ),
      );
      expect(attribution!.source, 'default');

      final missing = InviteAttributionLink.parse(
        Uri.parse('https://archiveme.app/invite?ref=archive_invite'),
      );
      expect(missing!.source, 'default');
    });

    test('non-invite links never parse', () {
      expect(
        InviteAttributionLink.parse(
          Uri.parse('https://archiveme.app/start?cohort=x'),
        ),
        isNull,
      );
      expect(
        InviteAttributionLink.parse(
          Uri.parse('https://archiveme.app/invite?ref=other&source=x'),
        ),
        isNull,
      );
      expect(
        InviteAttributionLink.parse(Uri.parse('https://archiveme.app/invite')),
        isNull,
      );
    });

    test('valid invite link persists first-touch source only once', () async {
      final prefs = _MemoryPrefs();
      final store = InviteAttributionStore(prefs: prefs);

      final redirect = await InviteAttributionLink.resolveInviteRedirect(
        Uri.parse(
          'https://archiveme.app/invite'
          '?ref=archive_invite&source=thread_return',
        ),
        store: store,
      );
      expect(redirect, '/record');

      var firstTouch = await store.firstTouch();
      expect(firstTouch!.ref, 'archive_invite');
      expect(firstTouch.source, 'thread_return');

      // A later invite open never overwrites the first touch.
      await InviteAttributionLink.resolveInviteRedirect(
        Uri.parse(
          'https://archiveme.app/invite'
          '?ref=archive_invite&source=proof_counter',
        ),
        store: store,
      );
      firstTouch = await store.firstTouch();
      expect(firstTouch!.source, 'thread_return');

      // Persisted payload is exactly ref + source — nothing else.
      expect(prefs.maps[InviteAttributionStore.prefsKey], {
        'ref': 'archive_invite',
        'source': 'thread_return',
      });
    });

    test('attribution received fires with source and ref only', () async {
      await InviteAttributionLink.resolveInviteRedirect(
        Uri.parse(
          'https://archiveme.app/invite'
          '?ref=archive_invite&source=belief_distance',
        ),
        store: InviteAttributionStore(prefs: _MemoryPrefs()),
      );
      final events = eventsNamed(
        ActivationFunnelAnalytics.inviteAttributionReceived,
      );
      expect(events, hasLength(1));
      expect(events.single.properties, {
        'source': 'belief_distance',
        'ref': 'archive_invite',
      });
    });

    test('non-invite links track nothing and still route safely', () async {
      final redirect = await InviteAttributionLink.resolveInviteRedirect(
        Uri.parse('https://archiveme.app/invite?ref=other'),
        store: InviteAttributionStore(prefs: _MemoryPrefs()),
      );
      expect(redirect, '/record');
      expect(
        eventsNamed(ActivationFunnelAnalytics.inviteAttributionReceived),
        isEmpty,
      );
    });

    test('malformed stored attribution reads as null', () async {
      final prefs = _MemoryPrefs();
      prefs.maps[InviteAttributionStore.prefsKey] = {
        'ref': 'other_channel',
        'source': 'weekly_review',
      };
      expect(await InviteAttributionStore(prefs: prefs).firstTouch(), isNull);
    });
  });

  group('Trigger gate', () {
    test('no source before any value moment', () {
      expect(
        ReferralInviteAfterValue.sourceFor(
          entryCount: 5,
          hasWeeklyReview: false,
          hasConnectedProofCounter: false,
        ),
        isNull,
      );
      expect(
        ReferralInviteAfterValue.shouldShow(
          entryCount: 5,
          hasWeeklyReview: false,
          hasConnectedProofCounter: false,
        ),
        isFalse,
      );
    });

    test('blocked before the first save and at one entry', () {
      for (final count in [0, 1]) {
        expect(
          ReferralInviteAfterValue.shouldShow(
            entryCount: count,
            hasWeeklyReview: true,
            hasConnectedProofCounter: true,
          ),
          isFalse,
          reason: 'entryCount=$count',
        );
      }
    });

    test('weekly review and proof counter are passive triggers', () {
      expect(
        ReferralInviteAfterValue.sourceFor(
          entryCount: 3,
          hasWeeklyReview: true,
          hasConnectedProofCounter: false,
        ),
        'weekly_review',
      );
      expect(
        ReferralInviteAfterValue.sourceFor(
          entryCount: 3,
          hasWeeklyReview: false,
          hasConnectedProofCounter: true,
        ),
        'proof_counter',
      );
    });

    test('a useful-yes becomes the strongest source', () {
      ReferralInviteAfterValue.recordValueFeedback(
        cardType: 'thread_return_evidence',
        useful: true,
      );
      expect(
        ReferralInviteAfterValue.sourceFor(
          entryCount: 3,
          hasWeeklyReview: true,
          hasConnectedProofCounter: true,
        ),
        'thread_return',
      );
    });

    test('a Pro retention yes is a trigger on its own', () {
      ReferralInviteAfterValue.recordProRetentionYes();
      expect(
        ReferralInviteAfterValue.sourceFor(
          entryCount: 3,
          hasWeeklyReview: false,
          hasConnectedProofCounter: false,
        ),
        'pro_retention_yes',
      );
    });

    test('feedback card types map to stable referral sources only', () {
      expect(
        ReferralInviteAfterValue.sourceForFeedbackCardType(
          'weekly_thread_review',
        ),
        'weekly_review',
      );
      expect(
        ReferralInviteAfterValue.sourceForFeedbackCardType(
          'thread_return_evidence',
        ),
        'thread_return',
      );
      expect(
        ReferralInviteAfterValue.sourceForFeedbackCardType('belief_distance'),
        'belief_distance',
      );
      expect(
        ReferralInviteAfterValue.sourceForFeedbackCardType(
          'archive_proof_counter',
        ),
        'proof_counter',
      );
      expect(
        ReferralInviteAfterValue.sourceForFeedbackCardType('anything_else'),
        isNull,
      );
    });

    test('a Not quite response suppresses the invite for the session', () {
      ReferralInviteAfterValue.recordValueFeedback(
        cardType: 'weekly_thread_review',
        useful: false,
      );
      expect(
        ReferralInviteAfterValue.shouldShow(
          entryCount: 3,
          hasWeeklyReview: true,
          hasConnectedProofCounter: true,
        ),
        isFalse,
      );
    });

    test('shown or dismissed hides it for the rest of the session', () {
      ReferralInviteAfterValue.shownThisSession = true;
      expect(
        ReferralInviteAfterValue.shouldShow(
          entryCount: 3,
          hasWeeklyReview: true,
          hasConnectedProofCounter: false,
        ),
        isFalse,
      );
      ReferralInviteAfterValue.resetSessionForTest();
      ReferralInviteAfterValue.dismissedThisSession = true;
      expect(
        ReferralInviteAfterValue.shouldShow(
          entryCount: 3,
          hasWeeklyReview: true,
          hasConnectedProofCounter: false,
        ),
        isFalse,
      );
    });
  });

  group('Invite card widget', () {
    late List<MethodCall> clipboardCalls;

    Future<void> pumpCard(
      WidgetTester tester, {
      String source = 'weekly_review',
      VoidCallback? onDismissed,
    }) async {
      clipboardCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReferralInviteCard(
              // Keyed by source so repeated pumps get fresh widget state.
              key: ValueKey('referral_card_$source'),
              source: source,
              onDismissed: onDismissed ?? () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the calm copy with one CTA and a clear way out', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text(ReferralInviteAfterValue.title), findsOneWidget);
      expect(find.text(ReferralInviteAfterValue.body), findsOneWidget);
      expect(find.text(ReferralInviteAfterValue.ctaLabel), findsOneWidget);
      expect(find.text(ReferralInviteAfterValue.dismissLabel), findsOneWidget);

      final seen = eventsNamed(ActivationFunnelAnalytics.referralInviteSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'source': 'weekly_review',
        'card_type': 'weekly_review',
      });
    });

    testWidgets('proof line renders above the body for every source', (
      tester,
    ) async {
      const expectedBySource = {
        'weekly_review': ReferralInviteAfterValue.weeklyReviewProofLine,
        'thread_return': ReferralInviteAfterValue.threadReturnProofLine,
        'belief_distance': ReferralInviteAfterValue.beliefDistanceProofLine,
        'proof_counter': ReferralInviteAfterValue.proofCounterProofLine,
        'pro_retention_yes': ReferralInviteAfterValue.proRetentionProofLine,
        // Unknown sources fall back to the default proof line.
        'something_else': ReferralInviteAfterValue.defaultProofLine,
      };
      for (final entry in expectedBySource.entries) {
        ActivationFunnelAnalytics.resetForTest();
        ActivationFunnelAnalytics.captureForTest(
          (event, properties) =>
              captured.add((event: event, properties: properties)),
        );
        await pumpCard(tester, source: entry.key);

        final proofLine = find.byKey(const Key('referral_proof_moment_line'));
        expect(proofLine, findsOneWidget);
        expect(
          (tester.widget<Text>(proofLine)).data,
          entry.value,
          reason: 'source ${entry.key} renders its own proof line',
        );
        // Above (never below) the unchanged invite body.
        expect(
          tester.getTopLeft(proofLine).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const Key('referral_invite_body'))).dy,
          ),
        );
        expect(find.text(ReferralInviteAfterValue.body), findsOneWidget);
      }
    });

    testWidgets('proof moment event fires once with source/card_type only', (
      tester,
    ) async {
      await pumpCard(tester);
      // A rebuild of the same card never re-fires the seen event.
      await pumpCard(tester);

      final events = eventsNamed(
        ActivationFunnelAnalytics.referralProofMomentSeen,
      );
      expect(events, hasLength(1));
      expect(events.single.properties, {
        'source': 'weekly_review',
        'card_type': 'weekly_review',
      });
    });

    testWidgets(
      'copy action writes the exact source-specific invite text plus link',
      (tester) async {
        await pumpCard(tester);
        await tester.tap(find.byKey(const Key('referral_invite_cta')));
        await tester.pump();

        expect(clipboardCalls, hasLength(1));
        expect(
          (clipboardCalls.single.arguments as Map)['text'],
          '${ReferralInviteAfterValue.weeklyReviewInviteText}\n'
          'https://archiveme.app/invite?ref=archive_invite&source=weekly_review',
        );
        expect(
          find.byKey(const Key('referral_invite_copied_line')),
          findsOneWidget,
        );
        final copied = eventsNamed(
          ActivationFunnelAnalytics.referralInviteCopied,
        );
        expect(copied, hasLength(1));
        expect(copied.single.properties, {
          'source': 'weekly_review',
          'card_type': 'weekly_review',
        });
        final linkCopied = eventsNamed(
          ActivationFunnelAnalytics.referralInviteLinkCopied,
        );
        expect(linkCopied, hasLength(1));
        expect(linkCopied.single.properties, {
          'source': 'weekly_review',
          'ref': 'archive_invite',
        });
      },
    );

    testWidgets('every source copies its own invite variant with its link', (
      tester,
    ) async {
      const expectedBySource = {
        'weekly_review': ReferralInviteAfterValue.weeklyReviewInviteText,
        'thread_return': ReferralInviteAfterValue.threadReturnInviteText,
        'belief_distance': ReferralInviteAfterValue.beliefDistanceInviteText,
        'proof_counter': ReferralInviteAfterValue.proofCounterInviteText,
        'pro_retention_yes': ReferralInviteAfterValue.proRetentionInviteText,
        // Unknown sources keep the default fallback available.
        'something_else': ReferralInviteAfterValue.inviteText,
      };
      for (final entry in expectedBySource.entries) {
        ActivationFunnelAnalytics.resetForTest();
        ActivationFunnelAnalytics.captureForTest(
          (event, properties) =>
              captured.add((event: event, properties: properties)),
        );
        await pumpCard(tester, source: entry.key);
        await tester.tap(find.byKey(const Key('referral_invite_cta')));
        await tester.pump();

        final linkSource = entry.key == 'something_else'
            ? 'default'
            : entry.key;
        expect(
          (clipboardCalls.single.arguments as Map)['text'],
          '${entry.value}\nhttps://archiveme.app/invite'
          '?ref=archive_invite&source=$linkSource',
          reason: 'source ${entry.key} copies its own invite variant + link',
        );
      }
    });

    testWidgets('dismiss fires the event and the callback', (tester) async {
      var dismissed = 0;
      await pumpCard(tester, onDismissed: () => dismissed++);
      await tester.tap(find.byKey(const Key('referral_invite_dismiss')));
      expect(dismissed, 1);
      final events = eventsNamed(
        ActivationFunnelAnalytics.referralInviteDismissed,
      );
      expect(events, hasLength(1));
      expect(events.single.properties, {
        'source': 'weekly_review',
        'card_type': 'weekly_review',
      });
    });

    testWidgets('analytics payloads carry whitelisted keys only', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const Key('referral_invite_cta')));
      await tester.pump();

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet(),
          e.event == ActivationFunnelAnalytics.referralInviteLinkCopied
              ? {'source', 'ref'}
              : {'source', 'card_type'},
          reason: '${e.event} carries unexpected keys',
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('deadline')));
        expect(flat, isNot(contains('voicememory')));
        // Neither the invite text nor the link ever enters analytics.
        expect(flat, isNot(contains('testing archiveme')));
        expect(flat, isNot(contains('want to try it')));
        expect(flat, isNot(contains('https://')));
      }
    });
  });

  group('Section reactivity', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      int entryCount = 3,
      bool hasWeeklyReview = false,
      bool hasConnectedProofCounter = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReferralInviteSection(
              entryCount: entryCount,
              hasWeeklyReview: hasWeeklyReview,
              hasConnectedProofCounter: hasConnectedProofCounter,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('appears right after a useful-yes lands in the session', (
      tester,
    ) async {
      await pumpSection(tester);
      expect(find.byKey(const Key('referral_invite_card')), findsNothing);

      ReferralInviteAfterValue.recordValueFeedback(
        cardType: 'belief_distance',
        useful: true,
      );
      await tester.pump();

      expect(find.byKey(const Key('referral_invite_card')), findsOneWidget);
      final seen = eventsNamed(ActivationFunnelAnalytics.referralInviteSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties['source'], 'belief_distance');
    });

    testWidgets('stays hidden after a Not quite even with a weekly review', (
      tester,
    ) async {
      ReferralInviteAfterValue.recordValueFeedback(
        cardType: 'weekly_thread_review',
        useful: false,
      );
      await pumpSection(tester, hasWeeklyReview: true);
      expect(find.byKey(const Key('referral_invite_card')), findsNothing);
    });
  });

  group('Insights screen integration', () {
    Future<void> pumpInsights(
      WidgetTester tester, {
      required List<PressureCheckInRecord> records,
      bool pro = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: pro),
            records: records,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no card before any value moment', (tester) async {
      await pumpInsights(tester, records: _noValueRecords());
      expect(find.byKey(const Key('referral_invite_card')), findsNothing);
    });

    testWidgets('no card with only one entry', (tester) async {
      await pumpInsights(tester, records: [_checkIn(id: 'a', daysAgo: 0)]);
      expect(find.byKey(const Key('referral_invite_card')), findsNothing);
    });

    testWidgets('appears below the weekly review once it exists', (
      tester,
    ) async {
      await pumpInsights(tester, records: _valueRecords());

      final card = find.byKey(const Key('referral_invite_card'));
      expect(card, findsOneWidget);
      // Below the value moment it follows — never above it.
      final reviewDy = tester
          .getTopLeft(find.byKey(const Key('weekly_thread_review_card')))
          .dy;
      expect(tester.getTopLeft(card).dy, greaterThan(reviewDy));
      final seen = eventsNamed(ActivationFunnelAnalytics.referralInviteSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties['source'], 'weekly_review');
    });

    testWidgets('dismiss hides it for the rest of the session', (tester) async {
      await pumpInsights(tester, records: _valueRecords());
      final dismiss = find.byKey(const Key('referral_invite_dismiss'));
      await tester.ensureVisible(dismiss);
      await tester.pump();
      await tester.tap(dismiss);
      await tester.pump();
      expect(find.byKey(const Key('referral_invite_card')), findsNothing);

      // A fresh screen in the same session shows nothing.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpInsights(tester, records: _valueRecords());
      expect(find.byKey(const Key('referral_invite_card')), findsNothing);
    });

    testWidgets('only one appearance per session across screens', (
      tester,
    ) async {
      await pumpInsights(tester, records: _valueRecords());
      expect(find.byKey(const Key('referral_invite_card')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpInsights(tester, records: _valueRecords());
      expect(find.byKey(const Key('referral_invite_card')), findsNothing);
    });

    testWidgets('feedback rows still work alongside the invite', (
      tester,
    ) async {
      await pumpInsights(tester, records: _valueRecords());
      final yes = find.byKey(
        const Key('value_feedback_yes_weekly_thread_review'),
      );
      await tester.ensureVisible(yes);
      await tester.pump();
      await tester.tap(yes);
      await tester.pump();
      expect(find.text(ValueAccuracyFeedbackRow.yesThanksLine), findsOneWidget);
    });
  });
}
