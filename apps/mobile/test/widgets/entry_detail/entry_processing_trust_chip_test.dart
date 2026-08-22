import 'package:archiveme_mobile/features/entry_detail/entry_processing_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/journal_proof_data.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_processing_trust_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({required bool usedOnnx}) {
  return _entryWithProof(JournalProofData(processingUsedOnnx: usedOnnx));
}

/// An entry saved by `_saveProvisionalNativeTranscript`: `SFSpeechRecognizer`
/// produced the transcript, so no ONNX ran and nothing was uploaded.
///
/// `processingUsedOnnx` is left unset, which is the null this path records —
/// "no claim about ONNX", as distinct from `false`, "it was sent instead".
JournalEntry _nativeSttEntry() {
  return _entryWithProof(
    const JournalProofData(processingUsedLocalStt: true),
  );
}

JournalEntry _entryWithProof(JournalProofData proof) {
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
    proof: proof,
  );
}

/// The label rule as it stood before `processingUsedLocalStt` was read.
///
/// Kept verbatim so the defect is demonstrated rather than described: once
/// `usedOnnx` became correctly null for `SFSpeechRecognizer` output, this
/// returns null and the most private path renders no chip at all.
String? _preFixLabelFor(JournalEntry entry) {
  final usedOnnx = entry.processingUsedOnnx;
  if (usedOnnx == null) return null;
  return usedOnnx
      ? EntryProcessingCopy.processedOnDevice
      : EntryProcessingCopy.sentForSecureProcessing;
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

  group('an on-device-only entry shows its provenance', () {
    test('the pre-fix rule rendered nothing for a SFSpeechRecognizer entry', () {
      // The defect, before the fix: the more private path got less
      // information than the one that uploaded audio.
      expect(_preFixLabelFor(_nativeSttEntry()), isNull);
    });

    testWidgets('a native-STT entry renders a chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EntryProcessingTrustChip(entry: _nativeSttEntry())),
        ),
      );

      expect(
        find.byKey(const Key('entry_processing_transcribed_on_device_chip')),
        findsOneWidget,
      );
    });

    testWidgets('it claims transcription, not processing', (tester) async {
      // `_saveProvisionalNativeTranscript` saves `analysisSucceeded: false`
      // and `SyncStatus.pendingUpload`, so "Processed on your device" would
      // name a step that did not run and imply the entry is not queued to go
      // anywhere.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EntryProcessingTrustChip(entry: _nativeSttEntry())),
        ),
      );

      expect(find.text(EntryProcessingCopy.transcribedOnDevice), findsOneWidget);
      expect(find.text(EntryProcessingCopy.processedOnDevice), findsNothing);
    });

    test('a cloud entry is unaffected by the local-STT arm', () {
      // `usedOnnx: false` still wins: an uploaded entry does not get a local
      // claim just because its transcript started on the device.
      final uploaded = _entryWithProof(
        const JournalProofData(
          processingUsedOnnx: false,
          processingUsedLocalStt: true,
        ),
      );
      expect(
        EntryProcessingTrustChip.labelFor(uploaded),
        EntryProcessingCopy.sentForSecureProcessing,
      );
    });

    test('an entry making no claim still renders nothing', () {
      final silent = _entryWithProof(const JournalProofData());
      expect(EntryProcessingTrustChip.labelFor(silent), isNull);
    });
  });
}
