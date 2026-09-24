import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/onboarding/first_session_evidence.dart';
import 'package:archiveme_mobile/features/onboarding/first_session_evidence_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:archiveme_mobile/widgets/onboarding/first_save_quote_receipt.dart';
import 'package:archiveme_mobile/widgets/onboarding/imported_pattern_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _note(String id, String transcript, DateTime createdAt) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('evidence flags stay off until reviewed', () {
    expect(V1CapabilityRegistry.onboardingImportFirst, isFalse);
    expect(V1CapabilityRegistry.firstSaveQuoteBack, isFalse);
  });

  test('copy lint passes the medical-claims ban list', () {
    const banned = [
      'therapy',
      'therapist dashboard',
      'clinical report',
      'diagnosis',
      'treatment',
      'mental health assessment',
      'medical record',
      'care plan',
      'doctor-ready diagnosis',
    ];
    for (final line in FirstSessionEvidenceCopy.allVisibleStrings) {
      final lower = line.toLowerCase();
      for (final term in banned) {
        expect(lower.contains(term), isFalse, reason: line);
      }
    }
  });

  testWidgets('import path yields a cited card', (tester) async {
    final entries = [
      _note(
        'a',
        'I felt pressure to say yes again before checking my capacity today.',
        DateTime(2026, 6, 1, 9),
      ),
      _note(
        'b',
        'I felt pressure to say yes before checking capacity at work today.',
        DateTime(2026, 6, 2, 9),
      ),
      _note(
        'c',
        'I felt pressure to say yes again and keep going when tired today.',
        DateTime(2026, 6, 3, 9),
      ),
    ];
    final model = ImportedPatternPresenter.fromEntries(entries);
    expect(model, isNotNull);
    expect(model!.entryIds, containsAll(['a', 'b', 'c']));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportedPatternCard(
            model: model,
            onViewEvidence: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('imported_pattern_card')), findsOneWidget);
    expect(find.text(FirstSessionEvidenceCopy.importCardTitle), findsOneWidget);
    expect(find.byType(ViewEvidenceInlineLink), findsOneWidget);
    expect(find.textContaining('pressure to say yes'), findsWidgets);
  });

  testWidgets('no-import path shows only verbatim quotes', (tester) async {
    final saved = JournalEntry(
      id: 'first',
      createdAt: DateTime(2026, 6, 12, 8, 30),
      transcript: 'I sat with the window open. The room was quiet.',
      durationSeconds: 12,
      localAudioPath: '/tmp/first.m4a',
      transcriptProvenance: TranscriptProvenance.speechToText,
      reflection: const Reflection(
        mood: 'calm',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: 'A model wrote this observation.',
        repeatedSignal: '',
      ),
    );
    final quotes = FirstSaveQuotePresenter.quotesFor(saved);
    expect(quotes, hasLength(2));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstSaveQuoteReceipt(
            quotes: quotes,
            audioPath: saved.localAudioPath,
            onPlay: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('first_save_quote_receipt')), findsOneWidget);
    expect(find.text(FirstSessionEvidenceCopy.quoteTitle), findsOneWidget);
    expect(find.text('I sat with the window open.'), findsOneWidget);
    expect(find.text('The room was quiet.'), findsOneWidget);
    expect(find.text('A model wrote this observation.'), findsNothing);
    expect(find.byKey(const Key('first_save_quote_play_chip')), findsOneWidget);
    expect(
      find.text(FirstSessionEvidenceCopy.remindQuestion),
      findsOneWidget,
    );
    expect(find.textContaining('you should'), findsNothing);
    expect(find.textContaining('pattern'), findsNothing);

    final edited = JournalEntry(
      id: 'edited',
      createdAt: DateTime(2026, 6, 12, 9),
      transcript: 'I typed this myself.',
      durationSeconds: 0,
      transcriptProvenance: TranscriptProvenance.userEdited,
      reflection: const Reflection(
        mood: 'calm',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
    expect(FirstSaveQuotePresenter.quotesFor(edited), isEmpty);
  });
}
