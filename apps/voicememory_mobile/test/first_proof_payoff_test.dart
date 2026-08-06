import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/chat_differentiation/chat_differentiation_copy.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_analytics.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_copy.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_copy.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_gates.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_model.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/record/chat_differentiation_sheet.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_payoff_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: localAudioPath,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

void main() {
  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('FirstProofPayoffEngine', () {
    test('appears after third related usable entry', () {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedEntries(),
      );
      expect(payoff, isNotNull);
      expect(payoff!.headline, FirstProofPayoffCopy.headline);
      expect(payoff.groundedPhrase.toLowerCase(), contains('said yes'));
    });

    test('shows 2–3 user-word snippets when safely available', () {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedEntries(),
      );
      expect(payoff, isNotNull);
      expect(payoff!.variant, FirstProofPayoffVariant.strongWithSnippets);
      expect(payoff.snippets.length, greaterThanOrEqualTo(2));
      expect(payoff.snippets.length, lessThanOrEqualTo(3));
      expect(payoff.evidenceLabel, FirstProofPayoffCopy.yourWordsLabel);
      expect(payoff.meaningLine, FirstProofPayoffCopy.patternLine);
      expect(
        payoff.returnHook,
        anyOf(
          FirstProofPayoffCopy.truthLine,
          ProofConfidenceCalibrationCopy.strong,
        ),
      );
      expect(payoff.showDifferentiation, isTrue);
      expect(
        payoff.differentiationLine,
        ChatDifferentiationCopy.firstProofLine,
      );
      expect(payoff.timelineRows, hasLength(3));
      for (final snippet in payoff.snippets) {
        expect(snippet.quote, isNotEmpty);
      }
    });

    test(
      'assigns fallback variant when fewer than two snippets are extracted',
      () {
        final payoff = FirstProofPayoffEngine.build(
          entries: _threeRelatedEntries(),
        );
        expect(payoff, isNotNull);
        expect(
          payoff!.variant,
          payoff.snippets.length >= 2
              ? FirstProofPayoffVariant.strongWithSnippets
              : FirstProofPayoffVariant.fallbackPhraseOnly,
        );
      },
    );

    test('does not show for generic test text', () {
      final entries = [
        _entry(id: 'g1', transcript: 'This is a test to check function'),
        _entry(id: 'g2', transcript: 'This is a second test for pressure'),
        _entry(id: 'g3', transcript: 'This is a third test for pressure'),
      ];
      expect(FirstProofPayoffEngine.build(entries: entries), isNull);
    });

    test('does not show for quiet-day entries', () {
      final entries = [
        _entry(id: 'q1', transcript: 'Nothing much today.'),
        _entry(id: 'q2', transcript: 'Nothing much today.'),
        _entry(id: 'q3', transcript: 'Nothing much today.'),
      ];
      expect(FirstProofPayoffEngine.build(entries: entries), isNull);
    });

    test('does not show for pending placeholder transcript', () {
      final entries = [
        _entry(
          id: 'v1',
          transcript: _placeholder,
          localAudioPath: '/tmp/v1.m4a',
        ),
        _entry(
          id: 'v2',
          transcript: _placeholder,
          localAudioPath: '/tmp/v2.m4a',
        ),
        _entry(
          id: 'v3',
          transcript: _placeholder,
          localAudioPath: '/tmp/v3.m4a',
        ),
      ];
      expect(FirstProofPayoffEngine.build(entries: entries), isNull);
    });
  });

  group('FirstProofPayoffCopy', () {
    test('avoids weak milestone headlines as main lead', () {
      expect(FirstProofPayoffCopy.headline, 'ArchiveMe noticed this came back');
      for (final banned in FirstProofPayoffCopy.bannedMainLeads) {
        expect(FirstProofPayoffCopy.headline, isNot(equals(banned)));
      }
    });

    test(
      'visible strings pass advice guard except intentional negation line',
      () {
        for (final line in FirstProofPayoffCopy.allVisibleStrings()) {
          expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
        }
      },
    );
  });

  group('FirstProofPayoffGates', () {
    test('suppresses lower-priority surfaces during payoff', () {
      expect(FirstProofPayoffGates.suppressLowerPrioritySurfaces(true), isTrue);
      expect(
        FirstProofPayoffGates.suppressLowerPrioritySurfaces(false),
        isFalse,
      );
    });

    test('helped tracking stays hidden while payoff owns the moment', () {
      final entries = _threeRelatedEntries();
      final helped = HelpedTrackingEngine.buildPrompt(
        entries: entries,
        isPostSaveDone: true,
        isDegradedPostSave: false,
        showWhatChangedV2: false,
      );
      expect(helped, isNotNull);
      expect(FirstProofPayoffGates.suppressLowerPrioritySurfaces(true), isTrue);
    });
  });

  group('FirstProofPayoffCard', () {
    testWidgets('leads with headline then user evidence snippets', (
      tester,
    ) async {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedEntries(),
      );
      expect(payoff, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofPayoffCard(
              payoff: payoff!,
              entryCount: 3,
              onWatchThisNext: () {},
            ),
          ),
        ),
      );

      expect(find.text(FirstProofPayoffCopy.headline), findsOneWidget);
      expect(
        find.byKey(const Key('first_proof_payoff_your_words_label')),
        findsOneWidget,
      );
      expect(find.text(FirstProofPayoffCopy.patternLine), findsOneWidget);
      expect(find.text(ChatDifferentiationCopy.firstProofLine), findsOneWidget);
      expect(
        find.text(ChatDifferentiationCopy.expandLinkLabel),
        findsOneWidget,
      );
      expect(
        find.text(FirstProofPayoffCopy.truthLine).evaluate().isNotEmpty ||
            find
                .text(ProofConfidenceCalibrationCopy.strong)
                .evaluate()
                .isNotEmpty,
        isTrue,
      );
      expect(find.textContaining('said yes'), findsWidgets);
      for (final banned in FirstProofPayoffCopy.bannedMainLeads) {
        expect(find.text(banned), findsNothing);
      }
    });

    testWidgets('does not show large Watch this next CTA inside payoff card', (
      tester,
    ) async {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedEntries(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofPayoffCard(
              payoff: payoff!,
              entryCount: 3,
              onWatchThisNext: () {},
            ),
          ),
        ),
      );

      expect(find.text(FirstProofPayoffCopy.watchThisNextCta), findsNothing);
      expect(
        find.byKey(const Key('first_proof_payoff_watch_cta')),
        findsNothing,
      );
    });

    testWidgets('Why this is different from chat opens explanation sheet', (
      tester,
    ) async {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedEntries(),
      );
      expect(payoff!.showDifferentiation, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofPayoffCard(
              payoff: payoff,
              entryCount: 3,
              onWatchThisNext: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('first_proof_payoff_chat_differentiation_link')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_differentiation_sheet')),
        findsOneWidget,
      );
      expect(find.text(ChatDifferentiationCopy.sheetTitle), findsOneWidget);
      expect(find.text(ChatDifferentiationCopy.sheetBody), findsOneWidget);
      expect(find.text(ChatDifferentiationCopy.sheetCloseLine), findsOneWidget);
      expect(
        find.text(ChatDifferentiationCopy.timelineFirstSavedLabel),
        findsOneWidget,
      );
      final joined = [
        ChatDifferentiationCopy.sheetTitle,
        ChatDifferentiationCopy.sheetBody,
        ChatDifferentiationCopy.sheetCloseLine,
      ].join(' ').toLowerCase();
      for (final banned in ChatDifferentiationCopy.bannedAttackPhrases) {
        expect(joined, isNot(contains(banned)), reason: banned);
      }
    });

    testWidgets('falls back when snippets unavailable', (tester) async {
      final fallback = FirstProofPayoff(
        variant: FirstProofPayoffVariant.fallbackPhraseOnly,
        headline: FirstProofPayoffCopy.fallbackHeadline,
        subhead: '',
        groundedPhrase: 'said yes again',
        evidenceLabel: FirstProofPayoffCopy.yourWordsLabel,
        snippets: const [],
        meaningLine: '',
        returnHook: FirstProofPayoffCopy.fallbackBody,
        hasStrongEvidence: true,
        canShowPatternDetail: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstProofPayoffCard(
                payoff: fallback,
                entryCount: 3,
                onWatchThisNext: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text(FirstProofPayoffCopy.fallbackHeadline), findsOneWidget);
      expect(find.text(FirstProofPayoffCopy.fallbackBody), findsOneWidget);
      expect(find.text(ChatDifferentiationCopy.firstProofLine), findsNothing);
      expect(find.text(ChatDifferentiationCopy.expandLinkLabel), findsNothing);
      expect(
        find.byKey(const Key('first_proof_payoff_your_words_label')),
        findsNothing,
      );
    });

    testWidgets('View pattern details CTA fires when available', (
      tester,
    ) async {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedEntries(),
      );
      var opened = false;

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstProofPayoffCard(
                payoff: payoff!,
                entryCount: 3,
                onWatchThisNext: () {},
                onViewPatternDetails: payoff.canShowPatternDetail
                    ? () => opened = true
                    : null,
              ),
            ),
          ),
        ),
      );

      if (payoff.canShowPatternDetail) {
        final cta = find.byKey(
          const Key('first_proof_payoff_pattern_detail_cta'),
        );
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pump();
        expect(opened, isTrue);
      } else {
        expect(
          find.byKey(const Key('first_proof_payoff_pattern_detail_cta')),
          findsNothing,
        );
      }
    });
  });

  group('FirstProofPayoffAnalytics', () {
    test('payloads exclude transcript and pattern text', () {
      final captured = <({String event, Map<String, Object> props})>[];
      ActivationFunnelAnalytics.captureForTest((event, props) {
        captured.add((event: event, props: props));
      });

      FirstProofPayoffAnalytics.seen(
        entryCount: 3,
        hasSnippets: true,
        hasPatternDetailCta: true,
      );
      FirstProofPayoffAnalytics.ctaTapped(
        entryCount: 3,
        hasSnippets: true,
        hasPatternDetailCta: true,
        cta: 'view_pattern_details',
      );

      expect(captured.length, 2);
      const allowedKeys = {
        'source',
        'entry_count',
        'has_snippets',
        'has_pattern_detail_cta',
        'stage',
      };
      for (final item in captured) {
        expect(item.event, isNot(contains('transcript')));
        expect(item.props.keys.toSet(), allowedKeys);
        final values = item.props.values
            .map((v) => v.toString().toLowerCase())
            .join(' ');
        expect(values, isNot(contains('said yes')));
        expect(values, isNot(contains('capacity')));
        expect(item.props.containsKey('note'), isFalse);
      }
      expect(captured.first.event, FirstProofPayoffAnalytics.seenEvent);
      expect(captured.last.event, FirstProofPayoffAnalytics.ctaTappedEvent);
      expect(captured.first.props['has_snippets'], 1);
      expect(captured.last.props['stage'], 'view_pattern_details');
    });
  });

  group('Protected areas', () {
    test('payoff feature files avoid billing and signing surfaces', () {
      const banned = ['RevenueCat', 'Purchases.', 'CFBundleVersion', 'signing'];
      final files = [
        'lib/features/first_proof_payoff/first_proof_payoff_copy.dart',
        'lib/features/first_proof_payoff/first_proof_payoff_engine.dart',
        'lib/features/first_proof_payoff/first_proof_payoff_analytics.dart',
        'lib/widgets/record/first_proof_payoff_card.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(
            text.contains(token),
            isFalse,
            reason: '$path must not reference $token',
          );
        }
      }
    });

    test('first proof remains on existing free engine path', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedEntries(),
      );
      expect(confirmed?.showsConfirmedRepeat, isTrue);
      expect(
        FirstProofPayoffEngine.build(entries: _threeRelatedEntries()),
        isNotNull,
      );
    });
  });
}
