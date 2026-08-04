import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/hallucination_guard/hallucination_guard_service.dart';

void main() {
  const transcript =
      'I felt overwhelmed after the meeting, but a short walk helped me reset.';
  final entry = JournalEntry(
    id: 'entry-1',
    createdAt: DateTime.utc(2026, 7, 1),
    transcript: transcript,
    durationSeconds: 42,
    reflection: const Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
  final guard = HallucinationGuardService(
    loadEntry: (id) async => id == entry.id ? entry : null,
  );

  test('marks a verbatim local transcript slice as verified', () async {
    final result = await guard.verify(
      const VerifiableCitation(
        sourceEntryId: 'entry-1',
        exactQuote: 'I felt overwhelmed after the meeting',
        audioTimestampMs: 1200,
        confidenceScore: .95,
      ),
    );
    expect(result.state, CitationVerificationState.verifiedQuote);
    expect(result.surroundingContext, contains('short walk'));
  });

  test('marks a semantic partial match as paraphrased', () async {
    final result = await guard.verify(
      const VerifiableCitation(
        sourceEntryId: 'entry-1',
        exactQuote: 'felt overwhelmed after meeting and walk helped reset',
        confidenceScore: .7,
      ),
    );
    expect(result.state, CitationVerificationState.paraphrased);
  });

  test('flags a quote that cannot be grounded locally', () async {
    final result = await guard.verify(
      const VerifiableCitation(
        sourceEntryId: 'entry-1',
        exactQuote: 'I was completely calm all day',
        confidenceScore: .4,
      ),
    );
    expect(result.state, CitationVerificationState.flagged);
  });
}
