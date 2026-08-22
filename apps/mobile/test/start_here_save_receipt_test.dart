import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/start_here_save_receipt_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/start_here_save_receipt_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/start_here_save_receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _engine = StartHereSaveReceiptEngine();

DailyReturnSuggestion _suggestion({
  String id = 'term_deadline',
  String title = 'What deadline pressure made you do',
  String prompt = 'What did deadline pressure make you rush or hide today?',
  String reason = 'You mentioned this before.',
  List<String> sourceTerms = const ['deadline'],
  String? evidenceSnippet,
}) {
  return DailyReturnSuggestion(
    id: id,
    title: title,
    prompt: prompt,
    reason: reason,
    sourceTerms: sourceTerms,
    evidenceSnippet: evidenceSnippet,
  );
}

const _bannedWords = [
  'must',
  'should',
  'problem',
  'unresolved',
  'failure',
  'lazy',
  'weak',
];

String _receiptCopy(StartHereSaveReceipt receipt) => [
  receipt.title,
  receipt.explanation,
  receipt.returnCueLine,
  receipt.freeValueLine,
  receipt.proContinuationLine,
  receipt.proCtaLabel,
  receipt.dismissLabel,
  ...receipt.proPreviewBullets,
  ...receipt.connectedTerms,
].join(' ').toLowerCase();

/// Pumps the receipt card inside a router with a `/subscription` capture
/// route, mirroring how the Record screen hosts it.
Future<PaywallRouteArgs? Function()> _pumpReceiptCard(
  WidgetTester tester, {
  required StartHereSaveReceipt receipt,
  VoidCallback? onDismiss,
}) async {
  PaywallRouteArgs? captured;
  await tester.binding.setSurfaceSize(const Size(390, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: StartHereSaveReceiptCard(
                receipt: receipt,
                onDismiss: onDismiss ?? () {},
              ),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) {
              captured = state.extra as PaywallRouteArgs?;
              return const Scaffold(
                body: Center(child: Text('SUBSCRIPTION_MARKER')),
              );
            },
          ),
        ],
      ),
    ),
  );
  await tester.pump();
  return () => captured;
}

void main() {
  group('Receipt engine — when a receipt exists', () {
    test('receipt generated after Start Here save', () {
      final receipt = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(),
      );
      expect(receipt, isNotNull);
      expect(receipt!.paywallSource, PaywallSource.startHereToday);
      expect(receipt.title, 'Saved to your archive');
      expect(
        receipt.explanation,
        'This connects to what your archive has already noticed.',
      );
      expect(receipt.proCtaLabel, 'See Pro');
      expect(receipt.dismissLabel, 'Not now');
    });

    test('receipt generated after Daily Suggestion save', () {
      final receipt = _engine.build(
        source: PaywallSource.dailySuggestion,
        suggestion: _suggestion(),
      );
      expect(receipt, isNotNull);
      expect(receipt!.paywallSource, PaywallSource.dailySuggestion);
    });

    test('no receipt after generic prompt save', () {
      expect(_engine.build(source: null, suggestion: _suggestion()), isNull);
      expect(
        _engine.build(
          source: PaywallSource.generalPro,
          suggestion: _suggestion(),
        ),
        isNull,
      );
      // A suggestion source without a retained suggestion also yields nothing.
      expect(
        _engine.build(source: PaywallSource.startHereToday, suggestion: null),
        isNull,
      );
    });
  });

  group('Receipt engine — connected terms', () {
    test('option-backed suggestions produce phrase-like labels', () {
      final receipt = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(
          id: 'recent_option_could_not_stop',
          sourceTerms: const [],
        ),
      );
      expect(receipt!.connectedTerms, contains('stopping felt unsafe'));

      final behind = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(
          id: 'recent_option_did_more_to_not_feel_behind',
          sourceTerms: const [],
        ),
      );
      expect(behind!.connectedTerms, contains('avoiding feeling behind'));
    });

    test('source terms become "<term> pressure" phrases', () {
      final receipt = _engine.build(
        source: PaywallSource.dailySuggestion,
        suggestion: _suggestion(sourceTerms: const ['deadline', 'work']),
      );
      expect(receipt!.connectedTerms, contains('deadline pressure'));
      expect(receipt.connectedTerms, contains('work pressure'));
    });

    test('connected terms capped at 3', () {
      final receipt = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(
          id: 'recent_option_guilty_resting',
          sourceTerms: const ['deadline', 'work', 'evening', 'morning'],
          evidenceSnippet: 'The deadline slipping again',
        ),
      );
      expect(receipt!.connectedTerms, hasLength(3));
    });

    test('generic terms filtered', () {
      final receipt = _engine.build(
        source: PaywallSource.dailySuggestion,
        suggestion: _suggestion(
          sourceTerms: const ['archive', 'today', 'pressure', 'deadline'],
          evidenceSnippet: 'something today',
        ),
      );
      expect(receipt!.connectedTerms, ['deadline pressure']);
    });

    test('user snippet appears as a connected term', () {
      final receipt = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(
          sourceTerms: const [],
          evidenceSnippet: 'The deadline slipping',
        ),
      );
      expect(receipt!.connectedTerms, contains('The deadline slipping'));
    });

    test('falls back to the suggestion title when nothing else exists', () {
      final receipt = _engine.build(
        source: PaywallSource.dailySuggestion,
        suggestion: _suggestion(
          id: 'todays_pressure',
          title: 'One honest moment',
          sourceTerms: const [],
        ),
      );
      expect(receipt!.connectedTerms, ['one honest moment']);
    });
  });

  group('Pro incentive copy', () {
    final receipt = _engine.build(
      source: PaywallSource.startHereToday,
      suggestion: _suggestion(),
    )!;

    test('receipt carries free value and Pro continuation copy', () {
      expect(receipt.freeValueLine, 'Today\u2019s save stays in your archive.');
      expect(
        receipt.proContinuationLine,
        'Pro keeps this thread connected across future recordings.',
      );
      expect(receipt.proPreviewBullets, const [
        'Track when this pattern returns',
        'See how the evidence changes',
        'Ask what keeps repeating',
      ]);
    });

    test('CTA and dismiss labels are unchanged', () {
      expect(receipt.proCtaLabel, 'See Pro');
      expect(receipt.dismissLabel, 'Not now');
    });

    test('copy never implies the saved recording disappears', () {
      final copy = _receiptCopy(receipt);
      for (final implied in [
        'disappear',
        'delete',
        'removed',
        'gone',
        'lose',
      ]) {
        expect(
          copy,
          isNot(contains(implied)),
          reason: 'receipt copy must not imply loss via "$implied"',
        );
      }
      // The free line states the save is kept, explicitly.
      expect(copy, contains('stays in your archive'));
    });

    test('no false scarcity wording', () {
      final copy = _receiptCopy(receipt);
      for (final scarcity in [
        'limited time',
        'expires',
        'lose access',
        'last chance',
      ]) {
        expect(
          copy,
          isNot(contains(scarcity)),
          reason: 'receipt copy must not use false scarcity "$scarcity"',
        );
      }
    });
  });

  group('Tomorrow return cue', () {
    const cue =
        'Come back tomorrow and your archive can check whether '
        'this thread appears again.';

    test('return cue exists for Start Here save', () {
      final receipt = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(),
      )!;
      expect(receipt.returnCueLine, cue);
    });

    test('return cue exists for Daily Suggestion save', () {
      final receipt = _engine.build(
        source: PaywallSource.dailySuggestion,
        suggestion: _suggestion(),
      )!;
      expect(receipt.returnCueLine, cue);
    });

    test('no receipt — and so no cue — for generic save', () {
      expect(_engine.build(source: null, suggestion: _suggestion()), isNull);
      expect(
        _engine.build(
          source: PaywallSource.generalPro,
          suggestion: _suggestion(),
        ),
        isNull,
      );
    });

    test('cue uses cautious wording, never certainty', () {
      final copy = cue.toLowerCase();
      expect(copy, contains('can check'));
      expect(copy, contains('whether'));
      expect(copy, contains('appears again'));

      final receipt = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(),
      )!;
      final all = _receiptCopy(receipt);
      for (final certainty in [
        'definitely',
        'will find',
        'always',
        'must',
        'should',
      ]) {
        expect(
          all,
          isNot(contains(certainty)),
          reason: 'receipt copy must avoid certainty word "$certainty"',
        );
      }
    });
  });

  group('Receipt copy guardrails', () {
    test('no banned words and no VoiceMemory in receipt copy', () {
      final receipt = _engine.build(
        source: PaywallSource.startHereToday,
        suggestion: _suggestion(
          id: 'recent_option_could_not_stop',
          sourceTerms: const ['deadline', 'work'],
        ),
      )!;
      final copy = _receiptCopy(receipt);
      for (final banned in _bannedWords) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'receipt copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('voicememory')));
    });

    test('all option phrases avoid banned and shaming words', () {
      const optionIds = [
        'could_not_stop',
        'did_more_to_not_feel_behind',
        'had_to_prove_enough',
        'guilty_resting',
        'kept_going_to_feel_productive',
      ];
      for (final id in optionIds) {
        final receipt = _engine.build(
          source: PaywallSource.startHereToday,
          suggestion: _suggestion(
            id: 'recent_option_$id',
            sourceTerms: const [],
          ),
        )!;
        final copy = _receiptCopy(receipt);
        for (final banned in _bannedWords) {
          expect(
            copy,
            isNot(contains(banned)),
            reason: 'option $id phrase must not contain "$banned"',
          );
        }
      }
    });
  });

  group('Receipt card widget', () {
    final richReceipt = _engine.build(
      source: PaywallSource.startHereToday,
      suggestion: _suggestion(
        id: 'recent_option_could_not_stop',
      ),
    )!;

    testWidgets('renders title, explanation, terms, CTA, and dismiss', (
      tester,
    ) async {
      await _pumpReceiptCard(tester, receipt: richReceipt);

      expect(find.text('Saved to your archive'), findsOneWidget);
      expect(
        find.text('This connects to what your archive has already noticed.'),
        findsOneWidget,
      );
      for (final term in richReceipt.connectedTerms) {
        expect(find.text(term), findsOneWidget);
      }
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('renders free value line, Pro continuation, and bullets', (
      tester,
    ) async {
      await _pumpReceiptCard(tester, receipt: richReceipt);

      expect(
        find.text('Today\u2019s save stays in your archive.'),
        findsOneWidget,
      );
      expect(
        find.text('Pro keeps this thread connected across future recordings.'),
        findsOneWidget,
      );
      for (final bullet in richReceipt.proPreviewBullets) {
        expect(find.text(bullet), findsOneWidget);
      }
    });

    testWidgets('renders the tomorrow return cue', (tester) async {
      await _pumpReceiptCard(tester, receipt: richReceipt);
      expect(find.text(richReceipt.returnCueLine), findsOneWidget);
    });

    testWidgets('cue sits after the terms and before the Pro incentive copy', (
      tester,
    ) async {
      await _pumpReceiptCard(tester, receipt: richReceipt);

      final termY = tester
          .getTopLeft(find.text(richReceipt.connectedTerms.first))
          .dy;
      final cueY = tester.getTopLeft(find.text(richReceipt.returnCueLine)).dy;
      final freeY = tester
          .getTopLeft(find.text('Today\u2019s save stays in your archive.'))
          .dy;

      expect(
        termY,
        lessThan(cueY),
        reason: 'connected terms must stay above the return cue',
      );
      expect(
        cueY,
        lessThan(freeY),
        reason: 'return cue must render before the Pro incentive copy',
      );
    });

    testWidgets('free value line renders above the Pro continuation line', (
      tester,
    ) async {
      await _pumpReceiptCard(tester, receipt: richReceipt);

      final freeY = tester
          .getTopLeft(find.text('Today\u2019s save stays in your archive.'))
          .dy;
      final proY = tester
          .getTopLeft(
            find.text(
              'Pro keeps this thread connected across future recordings.',
            ),
          )
          .dy;
      expect(
        freeY,
        lessThan(proY),
        reason: 'free value must be stated before the Pro continuation',
      );
    });

    testWidgets('connected terms stay visible above the Pro incentive copy', (
      tester,
    ) async {
      await _pumpReceiptCard(tester, receipt: richReceipt);

      final termY = tester
          .getTopLeft(find.text(richReceipt.connectedTerms.first))
          .dy;
      final freeY = tester
          .getTopLeft(find.text('Today\u2019s save stays in your archive.'))
          .dy;
      expect(termY, lessThan(freeY));
    });

    testWidgets('no auto-paywall before CTA tap', (tester) async {
      final captured = await _pumpReceiptCard(tester, receipt: richReceipt);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('SUBSCRIPTION_MARKER'), findsNothing);
      expect(captured(), isNull);
    });

    testWidgets('CTA routes to paywall with startHereToday', (tester) async {
      final captured = await _pumpReceiptCard(tester, receipt: richReceipt);

      await tester.tap(find.byKey(const Key('save_receipt_pro_cta')));
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.startHereToday);
      expect(captured()?.sourceRoute, '/record');
    });

    testWidgets('CTA routes to paywall with dailySuggestion', (tester) async {
      final receipt = _engine.build(
        source: PaywallSource.dailySuggestion,
        suggestion: _suggestion(),
      )!;
      final captured = await _pumpReceiptCard(tester, receipt: receipt);

      await tester.tap(find.byKey(const Key('save_receipt_pro_cta')));
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.dailySuggestion);
    });

    testWidgets('dismiss hides receipt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var visible = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: visible
                  ? StartHereSaveReceiptCard(
                      receipt: richReceipt,
                      onDismiss: () => setState(() => visible = false),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('start_here_save_receipt_card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('save_receipt_dismiss')));
      await tester.pump();

      expect(
        find.byKey(const Key('start_here_save_receipt_card')),
        findsNothing,
      );
    });
  });
}