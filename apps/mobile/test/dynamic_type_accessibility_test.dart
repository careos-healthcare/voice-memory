import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/source_quote_chip.dart';
import 'package:archiveme_mobile/features/onboarding/archive_journey_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/one_small_recording_model.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_service.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_read_aloud_button.dart';
import 'package:archiveme_mobile/widgets/onboarding/archive_journey_explainer_card.dart';
import 'package:archiveme_mobile/widgets/record/one_small_recording_card.dart';
import 'package:archiveme_research/screens/subscription_review_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const surface = Size(390, 844);

  Future<void> pumpAtTwice(
    WidgetTester tester,
    Widget child, {
    bool scroll = false,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: surface,
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('Record stays within the screen at 2x text and exposes Record', (
    tester,
  ) async {
    await pumpAtTwice(
      tester,
      OneSmallRecordingCard(
        recording: const OneSmallRecording(
          hasRecording: true,
          prompt: 'Say what happened today.',
        ),
        onRecordThis: (_) {},
      ),
      scroll: true,
    );
    expect(find.bySemanticsLabel('Record'), findsOneWidget);
  });

  testWidgets('Entry detail play and stop labels stay one control', (
    tester,
  ) async {
    await pumpAtTwice(
      tester,
      EntryReadAloudButton(
        text: 'A saved sentence from the entry.',
        offlineTts: OfflineTtsService(),
      ),
    );
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    expect(find.bySemanticsLabel('Stop'), findsNothing);
  });

  testWidgets('Archive explainer stays within the screen at 2x text', (
    tester,
  ) async {
    await pumpAtTwice(
      tester,
      ArchiveJourneyExplainerCard(explainer: ArchiveJourneyExplainer.full()),
      scroll: true,
    );
    expect(find.byType(ArchiveJourneyExplainerCard), findsOneWidget);
  });

  testWidgets('Paywall preview stays within the screen at 2x text', (
    tester,
  ) async {
    await pumpAtTwice(tester, const SubscriptionReviewPreviewScreen());
    expect(find.text('Keep the longer story'), findsOneWidget);
  });

  testWidgets('citation chip announces the quote as one label', (tester) async {
    const quote = 'I want to speak at the conference';
    final grounding = VerbatimEvidenceVerifier.verify(
      entryId: 'entry_1',
      candidate: quote,
      sourceText: '$quote, but I keep saying no.',
      recordedAt: DateTime(2026, 8, 14),
    );
    final evidence = grounding.evidence;
    expect(evidence, isNotNull);

    await pumpAtTwice(tester, SourceQuoteChip(evidence: evidence!));
    final semantics = tester.getSemantics(find.byKey(SourceQuoteChip.chipKey));
    expect(semantics.label, contains(quote));
    expect(semantics.label, contains('Quote:'));
    expect(semantics.label!.contains(' + '), isFalse);
  });
}
