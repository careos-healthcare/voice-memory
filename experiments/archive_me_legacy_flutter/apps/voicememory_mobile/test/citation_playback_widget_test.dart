import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/hallucination_guard/hallucination_guard_service.dart';
import 'package:voicememory_mobile/shared/ui/citation_playback_widget.dart';

void main() {
  testWidgets('verified quote tap emits source and timestamp playback intent', (
    tester,
  ) async {
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: DateTime.utc(2026, 7, 1),
      transcript: 'The exact words I recorded today.',
      durationSeconds: 30,
      reflection: const Reflection(
        mood: '',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
    final guard = HallucinationGuardService(loadEntry: (_) async => entry);
    CitationPlaybackIntent? intent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CitationPlaybackWidget(
            citation: const VerifiableCitation(
              sourceEntryId: 'entry-1',
              exactQuote: 'exact words I recorded',
              audioTimestampMs: 4200,
              confidenceScore: .96,
            ),
            guard: guard,
            onPlaybackIntent: (value) => intent = value,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Verified Quote'), findsOneWidget);
    await tester.tap(find.byKey(const Key('citation_entry-1')));
    expect(intent?.sourceEntryId, 'entry-1');
    expect(intent?.audioTimestampMs, 4200);
  });
}
