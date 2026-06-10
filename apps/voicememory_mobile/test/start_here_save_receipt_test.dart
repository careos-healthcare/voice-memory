import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/start_here_save_receipt_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/start_here_save_receipt_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/start_here_save_receipt_card.dart';

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
      receipt.proCtaLabel,
      receipt.dismissLabel,
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
      expect(receipt.proCtaLabel, 'See what Pro unlocks');
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
      expect(
        _engine.build(source: null, suggestion: _suggestion()),
        isNull,
      );
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
        expect(copy, isNot(contains(banned)),
            reason: 'receipt copy must not contain "$banned"');
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
          expect(copy, isNot(contains(banned)),
              reason: 'option $id phrase must not contain "$banned"');
        }
      }
    });
  });

  group('Receipt card widget', () {
    final richReceipt = _engine.build(
      source: PaywallSource.startHereToday,
      suggestion: _suggestion(
        id: 'recent_option_could_not_stop',
        sourceTerms: const ['deadline'],
      ),
    )!;

    testWidgets('renders title, explanation, terms, CTA, and dismiss',
        (tester) async {
      await _pumpReceiptCard(tester, receipt: richReceipt);

      expect(find.text('Saved to your archive'), findsOneWidget);
      expect(
        find.text('This connects to what your archive has already noticed.'),
        findsOneWidget,
      );
      for (final term in richReceipt.connectedTerms) {
        expect(find.text(term), findsOneWidget);
      }
      expect(find.text('See what Pro unlocks'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
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
