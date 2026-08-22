import 'dart:io';

import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/activation/activation_dropoff_review_copy.dart';
import 'package:archiveme_mobile/features/activation/activation_dropoff_review_engine.dart';
import 'package:archiveme_mobile/features/activation/activation_dropoff_review_model.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/widgets/debug/activation_dropoff_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ActivationDropoffCounters _filled({
  int appOpened = 1,
  int firstUsePromptSeen = 1,
  int firstMomentSaved = 0,
  int returnedAfterFirstMoment = 0,
  int secondMomentSaved = 0,
  int firstProofReached = 0,
  int returnedAfterFirstProof = 0,
  int fourthMomentSaved = 0,
  int returnCheckAnswered = 0,
  int proBoundarySeen = 0,
  int proTapped = 0,
}) => ActivationDropoffCounters(
  appOpened: appOpened,
  firstUsePromptSeen: firstUsePromptSeen,
  firstMomentSaved: firstMomentSaved,
  returnedAfterFirstMoment: returnedAfterFirstMoment,
  secondMomentSaved: secondMomentSaved,
  firstProofReached: firstProofReached,
  returnedAfterFirstProof: returnedAfterFirstProof,
  fourthMomentSaved: fourthMomentSaved,
  returnCheckAnswered: returnCheckAnswered,
  proBoundarySeen: proBoundarySeen,
  proTapped: proTapped,
);

void main() {
  group('ActivationDropoffReviewEngine', () {
    test('empty counters show all rows as Not reached', () {
      final review = ActivationDropoffReviewEngine.build(
        counters: const ActivationDropoffCounters(),
      );

      expect(review.rows, hasLength(11));
      for (final row in review.rows) {
        expect(row.count, 0);
        expect(row.status, ActivationDropoffRowStatus.notReached);
      }
      expect(
        review.bottleneckSummary,
        ActivationDropoffReviewCopy.bottleneckFirstMomentSaved,
      );
    });

    test('first moment saved resolves correct bottleneck', () {
      final review = ActivationDropoffReviewEngine.build(
        counters: _filled(firstMomentSaved: 1),
      );

      expect(
        review.bottleneckSummary,
        ActivationDropoffReviewCopy.bottleneckSecondMomentSaved,
      );
      expect(
        review.rows
            .firstWhere(
              (row) => row.id == ActivationDropoffRowId.firstMomentSaved,
            )
            .status,
        ActivationDropoffRowStatus.reached,
      );
    });

    test('second moment saved resolves correct bottleneck', () {
      final review = ActivationDropoffReviewEngine.build(
        counters: _filled(firstMomentSaved: 1, secondMomentSaved: 1),
      );

      expect(
        review.bottleneckSummary,
        ActivationDropoffReviewCopy.bottleneckFirstProofReached,
      );
    });

    test('first proof reached resolves correct bottleneck', () {
      final review = ActivationDropoffReviewEngine.build(
        counters: _filled(
          firstMomentSaved: 1,
          secondMomentSaved: 1,
          firstProofReached: 1,
        ),
      );

      expect(
        review.bottleneckSummary,
        ActivationDropoffReviewCopy.bottleneckReturnedAfterFirstProof,
      );
    });

    test(
      'return check answered resolves correct bottleneck when prior steps done',
      () {
        final review = ActivationDropoffReviewEngine.build(
          counters: _filled(
            firstMomentSaved: 1,
            secondMomentSaved: 1,
            firstProofReached: 1,
            returnedAfterFirstProof: 1,
          ),
        );

        expect(
          review.bottleneckSummary,
          ActivationDropoffReviewCopy.bottleneckReturnCheckAnswered,
        );
      },
    );

    test('Pro tapped resolves no critical bottleneck', () {
      final review = ActivationDropoffReviewEngine.build(
        counters: _filled(
          firstMomentSaved: 1,
          secondMomentSaved: 1,
          firstProofReached: 1,
          returnedAfterFirstProof: 1,
          returnCheckAnswered: 1,
          proTapped: 1,
        ),
      );

      expect(review.activationLoopComplete, isTrue);
      expect(
        review.bottleneckSummary,
        ActivationDropoffReviewCopy.bottleneckNone,
      );
    });

    test('missing counters do not crash', () {
      final review = ActivationDropoffReviewEngine.build(
        betaCounts: BetaActivationLoopCounts.fromMap(null),
      );

      expect(review.rows, hasLength(11));
      expect(review.bottleneckSummary, isNotEmpty);
    });

    test(
      'maps beta counts including confirmed repeat fallback for first proof',
      () {
        final counters = ActivationDropoffReviewEngine.fromBetaCounts(
          const BetaActivationLoopCounts(
            confirmedRepeatSeen: 2,
          ),
        );

        expect(counters.firstProofReached, 2);
      },
    );
  });

  group('ActivationDropoffReviewCard', () {
    tearDown(() {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = false;
    });

    testWidgets('debug gate hides card when developer settings locked', (
      tester,
    ) async {
      DeveloperSettingsGate.applyLoadedUnlock(false);
      DeveloperSettingsGate.suppressDebugBuildForTests = true;

      final review = ActivationDropoffReviewEngine.build(
        counters: const ActivationDropoffCounters(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivationDropoffReviewCard(review: review)),
        ),
      );

      expect(
        find.byKey(const Key('activation_dropoff_review_hidden')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activation_dropoff_review_card')),
        findsNothing,
      );
    });

    testWidgets('shows card when developer settings unlocked', (tester) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);

      final review = ActivationDropoffReviewEngine.build(
        counters: _filled(firstMomentSaved: 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivationDropoffReviewCard(review: review)),
        ),
      );

      expect(
        find.byKey(const Key('activation_dropoff_review_card')),
        findsOneWidget,
      );
      expect(find.text(ActivationDropoffReviewCopy.title), findsOneWidget);
      expect(
        find.text(ActivationDropoffReviewCopy.bottleneckLabel),
        findsOneWidget,
      );
    });
  });

  group('ActivationDropoffReviewCopy guard', () {
    test('no transcript or phrase text appears', () {
      final review = ActivationDropoffReviewEngine.build(
        counters: _filled(firstMomentSaved: 1),
      );
      final blob = [
        review.title,
        review.bottleneckLabel,
        review.bottleneckSummary,
        ...review.rows.map((row) => '${row.label} ${row.status.label}'),
      ].join('\n').toLowerCase();

      expect(blob, isNot(contains('transcript')));
      expect(blob, isNot(contains('said yes')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('therapy')));
    });
  });

  group('Billing isolation', () {
    test('billing RevenueCat restore untouched', () {
      final cardSource = File(
        'lib/widgets/debug/activation_dropoff_review_card.dart',
      ).readAsStringSync();
      expect(cardSource.toLowerCase(), isNot(contains('revenuecat')));
      expect(cardSource.toLowerCase(), isNot(contains('restorepurchase')));
      expect(cardSource.toLowerCase(), isNot(contains('billing')));
    });
  });

  group('Production UI isolation', () {
    test('settings screen does not import activation dropoff review card', () {
      final source = File(
        'lib/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(source.contains('activation_dropoff_review'), isFalse);
      expect(source.contains('ActivationDropoffReviewCard'), isFalse);
    });
  });
}