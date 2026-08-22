import 'package:archiveme_mobile/features/entry_detail/entry_processing_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/journal_proof_data.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_processing_trust_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({required bool usedOnnx}) {
  return JournalEntry(
    id: 'entry-processing',
    createdAt: DateTime.utc(2026, 6, 12),
    transcript: 'A long enough transcript for the processing trust chip test.',
    durationSeconds: 20,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 3,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: 'Observation text for chip test.',
      repeatedSignal: '',
    ),
    proof: JournalProofData(processingUsedOnnx: usedOnnx),
  );
}

void main() {
  group('EntryProcessingTrustChip', () {
    testWidgets('renders on-device label when processingUsedOnnx is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryProcessingTrustChip(entry: _entry(usedOnnx: true)),
          ),
        ),
      );

      expect(find.text(EntryProcessingCopy.processedOnDevice), findsOneWidget);
      expect(
        find.byKey(const Key('entry_processing_on_device_chip')),
        findsOneWidget,
      );
    });

    testWidgets('renders cloud label when processingUsedOnnx is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryProcessingTrustChip(entry: _entry(usedOnnx: false)),
          ),
        ),
      );

      expect(
        find.text(EntryProcessingCopy.sentForSecureProcessing),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('entry_processing_cloud_chip')),
        findsOneWidget,
      );
    });
  });
}
