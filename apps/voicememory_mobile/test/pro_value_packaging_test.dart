import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/pro/pro_value_preview_copy.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_copy.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_engine.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_models.dart';
import 'package:voicememory_mobile/screens/pro_value_preview_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

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
  'pro is active',
  'fake lock',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Start trial',
  'Limited time',
];

ProValueInput _defaultInput({bool purchasesAvailable = false}) =>
    ProValueInput(
      savedEntryCount: 5,
      depthLevel: ArchiveDepthLevel.weeklyReviewReady,
      watchlistCount: 2,
      weeklyReviewAvailable: true,
      evidenceMapContextCount: 3,
      beliefHistoryAvailable: true,
      purchasesAvailable: purchasesAvailable,
    );

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
  group('ProValueEngine', () {
    test('headline is deeper long-term evidence history', () {
      final plan = const ProValueEngine().build(_defaultInput());
      expect(plan.headline, ProValueCopy.headline);
      expect(
        plan.headline,
        'Free shows the first useful proof. Pro keeps the longer trail.',
      );
    });

    test('value bullets cover long-term Pro surfaces', () {
      final bullets = const ProValueEngine().build(_defaultInput()).valueBullets;
      expect(bullets, ProValueCopy.valueBullets);
      expect(bullets, contains('Longer evidence history'));
      expect(bullets, contains('Weekly archive reviews'));
      expect(bullets, contains('Timeline views over time'));
    });

    test('purchase unavailable copy keeps free archive usable', () {
      final plan = const ProValueEngine().build(_defaultInput());
      expect(
        plan.purchaseUnavailableNote.toLowerCase(),
        contains('purchases are not available yet'),
      );
      expect(
        plan.purchaseUnavailableNote.toLowerCase(),
        contains('free archive flow remains usable'),
      );
      expect(plan.primaryCta.route, '/record');
      expect(plan.secondaryCta.route, '/sample-archive');
    });

    test('card pro line is consistent across touchpoints', () {
      expect(ProValueCopy.cardProLine, ProValueCopy.headline);
    });

    test('copy avoids banned language and purchase CTAs', () {
      _expectNoBannedCopy(ProValueCopy.allVisibleCopy());
      final joined = ProValueCopy.allVisibleCopy().join('\n').toLowerCase();
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta.toLowerCase())));
      }
      expect(joined, isNot(contains('purchases are ready')));
      expect(joined, isNot(contains('pro is active')));
    });

    test('uses ArchiveMe branding only in visible copy', () {
      for (final text in ProValueCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(
        ProValueCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });
  });

  group('ProValuePreviewCopy delegates to central copy', () {
    test('preview copy matches ProValueCopy headline and bullets', () {
      expect(ProValuePreviewCopy.headline, ProValueCopy.headline);
      expect(ProValuePreviewCopy.proForBullets, ProValueCopy.valueBullets);
      expect(ProValuePreviewCopy.freeNowTitle, ProValueCopy.freeNowSectionTitle);
    });
  });

  group('Pro value preview screen', () {
    testWidgets('uses central Pro value headline and sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ProValuePreviewScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('pro_value_preview_headline')), findsOneWidget);
      expect(find.text(ProValueCopy.headline), findsOneWidget);
      expect(find.text(ProValueCopy.subheadline), findsOneWidget);
      expect(find.text(ProValueCopy.freeNowSectionTitle), findsOneWidget);
      expect(find.text(ProValueCopy.proForSectionTitle), findsOneWidget);
      expect(find.text(ProValueCopy.whySectionTitle), findsOneWidget);
      expect(find.text(ProValueCopy.purchaseSectionTitle), findsOneWidget);
      expect(find.text(ProValueCopy.primaryCtaLabel), findsOneWidget);
      expect(find.text(ProValueCopy.secondaryCtaLabel), findsOneWidget);
    });

    testWidgets('honestly says purchases are not available yet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ProValuePreviewScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Purchases are not available yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('free archive flow remains usable'),
        findsOneWidget,
      );
      for (final cta in _forbiddenPurchaseCtas) {
        expect(find.text(cta), findsNothing);
      }
    });
  });
}
