import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/share/archive_belief_share_card.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/share/archive_belief_share_card_widget.dart';

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
    ArchiveBeliefShareCard.resetSessionForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    ArchiveBeliefShareCard.resetSessionForTest();
  });

  group('Trigger rules', () {
    test('does not show before any value moment', () {
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: false,
        ),
        isFalse,
      );
    });

    test('shows after belief distance, weekly review, or thread return', () {
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: true,
          hasWeeklyReview: false,
          hasThreadReturn: false,
        ),
        isTrue,
      );
      expect(
        ArchiveBeliefShareCard.sourceFor(
          hasBeliefDistance: true,
          hasWeeklyReview: false,
          hasThreadReturn: false,
        ),
        'belief_distance',
      );
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: false,
          hasWeeklyReview: true,
          hasThreadReturn: false,
        ),
        isTrue,
      );
      expect(
        ArchiveBeliefShareCard.sourceFor(
          hasBeliefDistance: false,
          hasWeeklyReview: true,
          hasThreadReturn: false,
        ),
        'weekly_review',
      );
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: true,
        ),
        isTrue,
      );
      expect(
        ArchiveBeliefShareCard.sourceFor(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: true,
        ),
        'thread_return',
      );
    });

    test('a useful-yes on a value card becomes a trigger source', () {
      ArchiveBeliefShareCard.recordValueFeedback(
        cardType: 'thread_return_evidence',
        useful: true,
      );
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: false,
        ),
        isTrue,
      );
      expect(
        ArchiveBeliefShareCard.sourceFor(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: false,
        ),
        'thread_return',
      );
    });

    test('unknown feedback card types never become a trigger', () {
      ArchiveBeliefShareCard.recordValueFeedback(
        cardType: 'something_else',
        useful: true,
      );
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: false,
          hasWeeklyReview: false,
          hasThreadReturn: false,
        ),
        isFalse,
      );
    });

    test('does not show after a Not quite this session', () {
      ArchiveBeliefShareCard.recordValueFeedback(
        cardType: 'weekly_thread_review',
        useful: false,
      );
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: true,
          hasWeeklyReview: true,
          hasThreadReturn: true,
        ),
        isFalse,
      );
    });

    test('shows at most once per session and never after dismissal', () {
      ArchiveBeliefShareCard.shownThisSession = true;
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: true,
          hasWeeklyReview: true,
          hasThreadReturn: true,
        ),
        isFalse,
      );
      ArchiveBeliefShareCard.resetSessionForTest();
      ArchiveBeliefShareCard.dismissedThisSession = true;
      expect(
        ArchiveBeliefShareCard.shouldShow(
          hasBeliefDistance: true,
          hasWeeklyReview: true,
          hasThreadReturn: true,
        ),
        isFalse,
      );
    });
  });

  group('Copy guardrails', () {
    test('the five generalized lines are exact with stable ids', () {
      expect(ArchiveBeliefShareCard.lines, hasLength(5));
      const expected = {
        'returning_to': 'My archive noticed something I keep returning to.',
        'unnamed_pattern': 'My archive noticed a pattern I had not named yet.',
        'came_back': 'My archive noticed something that keeps coming back.',
        'may_be_changing': 'My archive noticed that something may be changing.',
        'returned_faded_changed':
            'My archive helped me compare what returned, faded, or changed.',
      };
      for (final line in ArchiveBeliefShareCard.lines) {
        expect(expected[line.id], line.text);
        expect(ArchiveBeliefShareCard.stableLineIds, contains(line.id));
      }
      expect(ArchiveBeliefShareCard.stableLineIds, expected.keys.toSet());
    });

    test('card frame copy is exact', () {
      expect(ArchiveBeliefShareCard.title, 'My ArchiveMe card');
      expect(
        ArchiveBeliefShareCard.footer,
        'Recorded privately with ArchiveMe',
      );
      expect(
        ArchiveBeliefShareCard.privacyLine,
        'No recordings or notes are shared.',
      );
      expect(ArchiveBeliefShareCard.copyCtaLabel, 'Copy card text');
      expect(ArchiveBeliefShareCard.shareCtaLabel, 'Share');
      expect(ArchiveBeliefShareCard.dismissLabel, 'Not now');
    });

    test('copied text is exact for the default line', () {
      expect(
        ArchiveBeliefShareCard.copiedTextFor('returning_to'),
        'My archive noticed something I keep returning to.  '
        'Recorded privately with ArchiveMe. '
        'No recordings or notes are shared.',
      );
    });

    test('unknown line ids produce no text', () {
      expect(ArchiveBeliefShareCard.copiedTextFor('something_else'), '');
      expect(ArchiveBeliefShareCard.lineFor('something_else'), isNull);
    });

    test('no counts, dates, emails, or URLs in any card or copied text', () {
      final allText = [
        ArchiveBeliefShareCard.title,
        ArchiveBeliefShareCard.pickerPrompt,
        ArchiveBeliefShareCard.footer,
        ArchiveBeliefShareCard.privacyLine,
        ArchiveBeliefShareCard.copyCtaLabel,
        ArchiveBeliefShareCard.shareCtaLabel,
        ArchiveBeliefShareCard.dismissLabel,
        ArchiveBeliefShareCard.copiedConfirmation,
        for (final line in ArchiveBeliefShareCard.lines) line.text,
        for (final id in ArchiveBeliefShareCard.stableLineIds)
          ArchiveBeliefShareCard.copiedTextFor(id),
      ].join(' ');
      // No numbers of any kind — counts and dates both need digits.
      expect(allText, isNot(matches(RegExp(r'[0-9]'))));
      expect(allText, isNot(contains('@')));
      expect(allText.toLowerCase(), isNot(contains('http')));
      expect(allText.toLowerCase(), isNot(contains('www.')));
    });

    test('no raw notes, snippets, belief phrases, or source terms', () {
      final allText = [
        for (final line in ArchiveBeliefShareCard.lines) line.text,
        for (final id in ArchiveBeliefShareCard.stableLineIds)
          ArchiveBeliefShareCard.copiedTextFor(id),
      ].join(' ').toLowerCase();
      // Note-like fixture content and source/context terms used across the
      // pressure fixtures must have no path into the card.
      for (final fragment in const [
        'deadline',
        'emails piling',
        'pressure moment',
        'could_not_stop',
        'guilty_resting',
        'had_to_prove_enough',
        'work',
        'transcript',
      ]) {
        expect(
          allText,
          isNot(contains(fragment)),
          reason: 'card copy must not contain "$fragment"',
        );
      }
    });

    test('no VoiceMemory and no banned words in any consumer-facing copy', () {
      final allCopy = [
        ArchiveBeliefShareCard.title,
        ArchiveBeliefShareCard.pickerPrompt,
        ArchiveBeliefShareCard.footer,
        ArchiveBeliefShareCard.privacyLine,
        ArchiveBeliefShareCard.copyCtaLabel,
        ArchiveBeliefShareCard.shareCtaLabel,
        ArchiveBeliefShareCard.dismissLabel,
        ArchiveBeliefShareCard.copiedConfirmation,
        for (final line in ArchiveBeliefShareCard.lines) line.text,
        for (final id in ArchiveBeliefShareCard.stableLineIds)
          ArchiveBeliefShareCard.copiedTextFor(id),
      ].join(' ');
      expect(allCopy.toLowerCase(), isNot(contains('voicememory')));
      expect(allCopy.toLowerCase(), isNot(contains('voice memory')));
      for (final banned in const [
        'therapy',
        'treatment',
        'diagnose',
        'definitely',
        'proves',
        'always',
        'never',
        'cure',
        'fixed',
        'broken',
        'weak',
        'lazy',
        'failure',
        'problem',
        'must',
        'should',
        'streak',
        'daily',
        'guilt',
      ]) {
        expect(
          allCopy.toLowerCase(),
          isNot(matches(RegExp('\\b$banned'))),
          reason: 'card copy must not contain "$banned"',
        );
      }
    });

    test('lines claim noticing, not knowing — hedged, no certainty', () {
      for (final line in ArchiveBeliefShareCard.lines) {
        expect(
          line.text.startsWith('My archive noticed') ||
              line.text.startsWith('My archive helped me'),
          isTrue,
          reason: 'lines speak for the archive, hedged: "${line.text}"',
        );
      }
    });
  });

  group('Section gating (widget)', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      required bool hasBeliefDistance,
      required bool hasWeeklyReview,
      required bool hasThreadReturn,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveBeliefShareSection(
                hasBeliefDistance: hasBeliefDistance,
                hasWeeklyReview: hasWeeklyReview,
                hasThreadReturn: hasThreadReturn,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders nothing before a value moment', (tester) async {
      await pumpSection(
        tester,
        hasBeliefDistance: false,
        hasWeeklyReview: false,
        hasThreadReturn: false,
      );
      expect(find.byKey(const Key('archive_belief_share_card')), findsNothing);
      expect(
        eventsNamed(ActivationFunnelAnalytics.archiveBeliefShareCardSeen),
        isEmpty,
      );
    });

    testWidgets('renders nothing after a Not quite this session', (
      tester,
    ) async {
      ArchiveBeliefShareCard.recordValueFeedback(
        cardType: 'belief_distance',
        useful: false,
      );
      await pumpSection(
        tester,
        hasBeliefDistance: true,
        hasWeeklyReview: true,
        hasThreadReturn: true,
      );
      expect(find.byKey(const Key('archive_belief_share_card')), findsNothing);
    });

    testWidgets('renders after a belief distance value moment', (tester) async {
      await pumpSection(
        tester,
        hasBeliefDistance: true,
        hasWeeklyReview: false,
        hasThreadReturn: false,
      );
      expect(
        find.byKey(const Key('archive_belief_share_card')),
        findsOneWidget,
      );
      final seen = eventsNamed(
        ActivationFunnelAnalytics.archiveBeliefShareCardSeen,
      );
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'source': 'belief_distance',
        'card_type': 'archive_belief_share',
      });
    });

    testWidgets('dismiss hides the card for the session', (tester) async {
      await pumpSection(
        tester,
        hasBeliefDistance: false,
        hasWeeklyReview: true,
        hasThreadReturn: false,
      );
      await tester.tap(find.byKey(const Key('archive_belief_share_dismiss')));
      await tester.pump();
      expect(find.byKey(const Key('archive_belief_share_card')), findsNothing);
      expect(ArchiveBeliefShareCard.dismissedThisSession, isTrue);
      final dismissed = eventsNamed(
        ActivationFunnelAnalytics.archiveBeliefShareDismissed,
      );
      expect(dismissed, hasLength(1));
      expect(dismissed.single.properties, {
        'source': 'weekly_review',
        'card_type': 'archive_belief_share',
      });
    });
  });

  group('Card widget', () {
    late List<MethodCall> clipboardCalls;
    late List<String> sharedTexts;

    Future<void> pumpCard(
      WidgetTester tester, {
      String source = 'belief_distance',
      VoidCallback? onDismissed,
    }) async {
      clipboardCalls = [];
      sharedTexts = [];
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
            body: SingleChildScrollView(
              child: ArchiveBeliefShareCardWidget(
                key: ValueKey('belief_share_card_$source'),
                source: source,
                onDismissed: onDismissed ?? () {},
                onShare: (text) async => sharedTexts.add(text),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('all five fixed generalized lines render as choices', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text(ArchiveBeliefShareCard.title), findsOneWidget);
      for (final line in ArchiveBeliefShareCard.lines) {
        expect(
          find.byKey(Key('archive_belief_share_line_${line.id}')),
          findsOneWidget,
        );
        expect(find.text(line.text), findsOneWidget);
      }
      expect(find.text(ArchiveBeliefShareCard.copyCtaLabel), findsOneWidget);
      expect(find.text(ArchiveBeliefShareCard.dismissLabel), findsOneWidget);
    });

    testWidgets('copy and share stay disabled until a line is chosen', (
      tester,
    ) async {
      await pumpCard(tester);
      final copyButton = tester.widget<FilledButton>(
        find.byKey(const Key('archive_belief_share_copy')),
      );
      expect(copyButton.onPressed, isNull);
      // No preview either — nothing exists to copy before approval.
      expect(
        find.byKey(const Key('archive_belief_share_preview')),
        findsNothing,
      );
      expect(clipboardCalls, isEmpty);
      expect(sharedTexts, isEmpty);
    });

    testWidgets('selecting a line shows the approved preview', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('archive_belief_share_line_came_back')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('archive_belief_share_preview')),
        findsOneWidget,
      );
      // The preview shows exactly what will be copied: line + footer +
      // privacy line. The line text also exists once in the picker above.
      final preview = find.byKey(const Key('archive_belief_share_preview'));
      expect(
        find.descendant(
          of: preview,
          matching: find.text(
            'My archive noticed something that keeps coming back.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.text(ArchiveBeliefShareCard.footer),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.text(ArchiveBeliefShareCard.privacyLine),
        ),
        findsOneWidget,
      );

      final selected = eventsNamed(
        ActivationFunnelAnalytics.archiveBeliefShareLineSelected,
      );
      expect(selected, hasLength(1));
      expect(selected.single.properties, {
        'source': 'belief_distance',
        'card_type': 'archive_belief_share',
        'line_id': 'came_back',
      });
    });

    testWidgets('copy writes the exact approved text to the clipboard', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('archive_belief_share_line_returning_to')),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('archive_belief_share_copy')),
      );
      await tester.tap(find.byKey(const Key('archive_belief_share_copy')));
      await tester.pump();

      expect(clipboardCalls, hasLength(1));
      expect(
        clipboardCalls.single.arguments['text'],
        'My archive noticed something I keep returning to.  '
        'Recorded privately with ArchiveMe. '
        'No recordings or notes are shared.',
      );
      expect(
        find.text(ArchiveBeliefShareCard.copiedConfirmation),
        findsOneWidget,
      );

      final copied = eventsNamed(
        ActivationFunnelAnalytics.archiveBeliefShareCopied,
      );
      expect(copied, hasLength(1));
      expect(copied.single.properties, {
        'source': 'belief_distance',
        'card_type': 'archive_belief_share',
        'line_id': 'returning_to',
      });
    });

    testWidgets('share hands the same approved text to the share hook', (
      tester,
    ) async {
      await pumpCard(tester, source: 'weekly_review');
      await tester.tap(
        find.byKey(
          const Key('archive_belief_share_line_returned_faded_changed'),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('archive_belief_share_share')),
      );
      await tester.tap(find.byKey(const Key('archive_belief_share_share')));
      await tester.pump();

      expect(sharedTexts, hasLength(1));
      expect(
        sharedTexts.single,
        ArchiveBeliefShareCard.copiedTextFor('returned_faded_changed'),
      );
      // Nothing went to the clipboard — sharing is its own explicit act.
      expect(clipboardCalls, isEmpty);

      final copied = eventsNamed(
        ActivationFunnelAnalytics.archiveBeliefShareCopied,
      );
      expect(copied, hasLength(1));
      expect(copied.single.properties, {
        'source': 'weekly_review',
        'card_type': 'archive_belief_share',
        'line_id': 'returned_faded_changed',
      });
    });

    testWidgets('analytics payloads carry only whitelisted stable ids', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('archive_belief_share_line_may_be_changing')),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('archive_belief_share_copy')),
      );
      await tester.tap(find.byKey(const Key('archive_belief_share_copy')));
      await tester.pump();

      expect(captured, isNotEmpty);
      const allowedKeys = {'source', 'card_type', 'line_id'};
      const allowedEvents = {
        ActivationFunnelAnalytics.archiveBeliefShareCardSeen,
        ActivationFunnelAnalytics.archiveBeliefShareLineSelected,
        ActivationFunnelAnalytics.archiveBeliefShareCopied,
        ActivationFunnelAnalytics.archiveBeliefShareDismissed,
        ActivationFunnelAnalytics.archiveShareAction,
      };
      for (final event in captured) {
        expect(allowedEvents, contains(event.event));
        for (final entry in event.properties.entries) {
          if (event.event == ActivationFunnelAnalytics.archiveShareAction) {
            expect({
              'source',
              'card_type',
              'share_type',
              'status',
            }, contains(entry.key));
            continue;
          }
          expect(allowedKeys, contains(entry.key));
          final value = entry.value as String;
          // Stable-id shape only — never sentence-like card text. Spaces
          // and punctuation cannot match, so no full line, note, snippet,
          // or belief phrase can ever be a value.
          expect(value, matches(RegExp(r'^[a-z0-9_]{1,40}$')));
        }
        if (event.properties.containsKey('line_id')) {
          expect(
            ArchiveBeliefShareCard.stableLineIds,
            contains(event.properties['line_id']),
          );
        }
      }
    });
  });
}
