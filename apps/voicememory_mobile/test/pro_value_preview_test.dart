import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/pro/pro_value_preview_copy.dart';
import 'package:voicememory_mobile/features/pro/pro_value_preview_gates.dart';
import 'package:archiveme_research/screens/pro_value_preview_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro_value_preview_card.dart';
import 'support/test_storage_sandbox.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Start trial',
  'Limited time',
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pro value preview copy', () {
    test('uses ArchiveMe branding and avoids banned language', () {
      _expectNoBannedCopy(ProValuePreviewCopy.allVisibleCopy());
      for (final text in ProValuePreviewCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        ProValuePreviewCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });

    test('does not include purchase CTAs in visible copy', () {
      final joined = ProValuePreviewCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });
  });

  group('Pro value preview gates', () {
    test('archive promo hidden before three entries', () {
      expect(
        ProValuePreviewGates.showArchivePromo(entryCount: 2, dismissed: false),
        isFalse,
      );
    });

    test('archive promo shown at three or more entries', () {
      expect(
        ProValuePreviewGates.showArchivePromo(entryCount: 3, dismissed: false),
        isTrue,
      );
    });

    test('archive promo hidden when dismissed', () {
      expect(
        ProValuePreviewGates.showArchivePromo(entryCount: 5, dismissed: true),
        isFalse,
      );
    });
  });

  group('Pro value preview screen', () {
    testWidgets('route opens and explains free and Pro value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ProValuePreviewScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('pro_value_preview_screen')), findsOneWidget);
      expect(find.text(ProValuePreviewCopy.freeNowTitle), findsOneWidget);
      expect(
        find.text(ProValuePreviewCopy.freeNowBullets.first),
        findsOneWidget,
      );
      expect(find.text(ProValuePreviewCopy.proForTitle), findsOneWidget);
      expect(
        find.text(ProValuePreviewCopy.proForBullets.first),
        findsOneWidget,
      );
      expect(find.text(ProValuePreviewCopy.whyTitle), findsOneWidget);
      expect(find.text(ProValuePreviewCopy.headline), findsOneWidget);
    });

    testWidgets('honestly says purchases are not available yet', (
      tester,
    ) async {
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

    testWidgets('has keep building and sample archive CTAs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ProValuePreviewScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pro_value_preview_keep_building_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pro_value_preview_sample_archive_cta')),
        findsOneWidget,
      );
      expect(find.text(ProValuePreviewCopy.keepBuildingCta), findsOneWidget);
      expect(
        find.text(ProValuePreviewCopy.trySampleArchiveCta),
        findsOneWidget,
      );
    });
  });

  group('Pro value preview settings', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
        skipRevenueCat: true,
      );
    });

    tearDown(() => sandbox.dispose());

    testWidgets('settings shows ArchiveMe Pro row', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
          GoRoute(
            path: '/pro-preview',
            builder: (_, _) => const ProValuePreviewScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.dragUntilVisible(
        find.byKey(const Key('settings_pro_value_preview_tile')),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('settings_pro_value_preview_tile')),
        findsOneWidget,
      );
      expect(find.text(ProValuePreviewCopy.settingsTitle), findsOneWidget);
      expect(find.text(ProValuePreviewCopy.settingsSubtitle), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('settings_pro_value_preview_tile')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('pro_value_preview_screen')), findsOneWidget);
    });
  });

  group('Pro value preview promo card', () {
    testWidgets('promo card navigates to pro preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => ProValuePreviewPromoCard(onDismiss: () {}),
              ),
              GoRoute(
                path: '/pro-preview',
                builder: (_, _) => const ProValuePreviewScreen(),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('pro_value_preview_promo_cta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pro_value_preview_screen')), findsOneWidget);
    });
  });

  group('Pro value preview router', () {
    test('app router includes pro-preview route', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/pro-preview'"));
    });
  });
}
