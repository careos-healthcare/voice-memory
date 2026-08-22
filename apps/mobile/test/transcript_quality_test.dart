import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranscriptQuality', () {
    test('rejects ellipsis', () {
      final verdict = TranscriptQuality.evaluate('...');
      expect(verdict.isValid, isFalse);
      expect(verdict.reason, 'blocked_phrase');
    });

    test('rejects punctuation-only transcript', () {
      expect(TranscriptQuality.evaluate('!!!').isValid, isFalse);
      expect(TranscriptQuality.evaluate('— —').isValid, isFalse);
      expect(TranscriptQuality.evaluate('...').reason, 'blocked_phrase');
    });

    test('rejects um', () {
      final verdict = TranscriptQuality.evaluate('um');
      expect(verdict.isValid, isFalse);
      expect(verdict.reason, 'blocked_phrase');
    });

    test('rejects short junk transcript', () {
      expect(TranscriptQuality.evaluate('ok').isValid, isFalse);
      expect(TranscriptQuality.evaluate('hi there').isValid, isFalse);
      expect(TranscriptQuality.evaluate('a b c d').isValid, isFalse);
    });

    test('accepts valid short sentence', () {
      final verdict = TranscriptQuality.evaluate('I felt pressure today');
      expect(verdict.isValid, isTrue);
      expect(verdict.normalized, 'I felt pressure today');
    });

    test('trims whitespace before evaluating', () {
      final verdict = TranscriptQuality.evaluate('  I felt pressure today  ');
      expect(verdict.isValid, isTrue);
      expect(verdict.normalized, 'I felt pressure today');
    });

    test('rejects empty text', () {
      expect(TranscriptQuality.evaluate('').isValid, isFalse);
      expect(TranscriptQuality.evaluate('   ').isValid, isFalse);
    });

    test('rejects blocked filler tokens case-insensitively', () {
      expect(TranscriptQuality.evaluate('UM').isValid, isFalse);
      expect(TranscriptQuality.evaluate('Hmm').isValid, isFalse);
    });
  });
}