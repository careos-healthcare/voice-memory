import 'package:archiveme_mobile/features/belief_evidence/evidence/journal_transcript_evidence_indexer.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/contradiction_detection/statement_analysis.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

/// Analysis output. Never the user's words, so it must never be quotable.
const _reflectionObservation =
    'You tend to say yes before checking your capacity.';
const _reflectionExactLanguage = 'I keep overcommitting to people at work.';
const _reflectionTension = 'You want rest but you keep filling the calendar.';

/// Speech-to-text output. The only quotable text.
const _spokenTranscript =
    'I said yes to the extra project even though I am already stretched.';

const _draftPlaceholder =
    '[draft] Recording saved locally — transcribe when connected';

Reflection _reflection() => const Reflection(
  mood: 'tired',
  emotionalIntensity: 3,
  recurringThemes: ['work'],
  exactLanguagePattern: _reflectionExactLanguage,
  concreteObservation: _reflectionObservation,
  repeatedSignal: 'overcommitment',
  tensionOrContradiction: _reflectionTension,
);

JournalEntry _entry({
  required String transcript,
  TranscriptProvenance provenance = TranscriptProvenance.speechToText,
}) => JournalEntry(
  id: 'entry-1',
  createdAt: DateTime.utc(2026, 6, 1),
  transcript: transcript,
  durationSeconds: 42,
  reflection: _reflection(),
  transcriptProvenance: provenance,
);

void main() {
  setUp(TranscriptEvidenceIndex.resetForTest);
  tearDown(TranscriptEvidenceIndex.resetForTest);

  group('failed transcription never contaminates entry.transcript', () {
    test('empty speech-to-text leaves the transcript empty', () {
      final applied = applyFinalTranscriptToVoiceEntry(
        _entry(transcript: ''),
        finalTranscript: null,
        provenance: TranscriptProvenance.speechToText,
      );

      expect(applied.transcript, isEmpty);
      expect(applied.transcript, isNot(contains(_reflectionObservation)));
      expect(applied.transcript, isNot(contains(_reflectionExactLanguage)));
    });

    test('a draft placeholder is not upgraded into a reflection quote', () {
      final applied = applyFinalTranscriptToVoiceEntry(
        _entry(transcript: _draftPlaceholder),
        finalTranscript: null,
        provenance: TranscriptProvenance.speechToText,
        draftPlaceholder: _draftPlaceholder,
      );

      expect(applied.transcript, _draftPlaceholder);
      expect(applied.transcript, isNot(contains(_reflectionObservation)));
    });

    test('the resolver has no parameter a reflection field could enter', () {
      expect(resolveFinalCaptureTranscript(transcript: null), isNull);
      expect(resolveFinalCaptureTranscript(transcript: ''), isNull);
      expect(resolveFinalCaptureTranscript(transcript: _draftPlaceholder), isNull);
      expect(
        resolveFinalCaptureTranscript(transcript: _spokenTranscript),
        _spokenTranscript,
      );
    });

    test('display still falls back to reflection text without persisting it', () {
      final entry = _entry(transcript: '');
      final resolution = resolveEntryDisplayText(entry);

      expect(resolution.text, _reflectionObservation);
      expect(resolution.source, EntryDisplayTextSource.body);
      expect(entry.transcript, isEmpty);
    });
  });

  group('the evidence index cannot ingest generated text', () {
    test('a failed-transcription entry registers no source at all', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(_entry(transcript: ''));
      expect(TranscriptEvidenceIndex.hasSource('entry-1'), isFalse);

      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(transcript: _draftPlaceholder),
      );
      expect(TranscriptEvidenceIndex.hasSource('entry-1'), isFalse);
      expect(TranscriptEvidenceIndex.sourceCount, 0);
    });

    test('a real transcript is indexed, and only the transcript', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(transcript: _spokenTranscript),
      );

      expect(TranscriptEvidenceIndex.transcriptFor('entry-1'), _spokenTranscript);
      expect(
        TranscriptEvidenceIndex.transcriptFor('entry-1'),
        isNot(contains(_reflectionObservation)),
      );
    });

    test('SpokenTranscript refuses placeholder and empty capture text', () {
      expect(
        SpokenTranscript.fromCaptureText(entryId: 'e', transcript: null),
        isNull,
      );
      expect(
        SpokenTranscript.fromCaptureText(entryId: 'e', transcript: '   '),
        isNull,
      );
      expect(
        SpokenTranscript.fromCaptureText(
          entryId: 'e',
          transcript: _draftPlaceholder,
        ),
        isNull,
      );
      expect(
        SpokenTranscript.fromCaptureText(entryId: '', transcript: _spokenTranscript),
        isNull,
      );
    });
  });

  group('statement selection never quotes a reflection field', () {
    test('the transcript is the head of the matching corpus', () {
      final texts = archiveStatementTexts(_entry(transcript: _spokenTranscript));

      expect(texts.first, _spokenTranscript);
      expect(texts, contains(_reflectionObservation));
      expect(texts, contains(_reflectionExactLanguage));
      expect(texts, contains(_reflectionTension));
    });

    test('the quotable accessor yields the transcript only', () {
      expect(
        archiveQuotableStatementText(_entry(transcript: _spokenTranscript)),
        _spokenTranscript,
      );
    });

    test('no transcript means no quote, rather than a reflection quote', () {
      expect(archiveQuotableStatementText(_entry(transcript: '')), isNull);
      expect(
        archiveQuotableStatementText(_entry(transcript: _draftPlaceholder)),
        isNull,
      );
    });

    test('a reflection field is never returned as a quote', () {
      for (final transcript in ['', '   ', _draftPlaceholder, 'too short']) {
        final quote = archiveQuotableStatementText(_entry(transcript: transcript));
        expect(quote, isNot(_reflectionObservation));
        expect(quote, isNot(_reflectionExactLanguage));
        expect(quote, isNot(_reflectionTension));
      }
    });
  });
}
