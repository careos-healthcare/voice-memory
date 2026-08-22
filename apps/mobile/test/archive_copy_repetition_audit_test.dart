import 'package:archiveme_mobile/features/copy_quality/archive_copy_repetition_audit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _captureLogs(void Function() body) {
  final logs = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    body();
  } finally {
    debugPrint = previous;
  }
  return logs;
}

void main() {
  group('ArchiveCopyRepetitionAudit', () {
    test('flags repeated generic words on the same screen', () {
      final result = ArchiveCopyRepetitionAudit.checkScreen(
        screenName: 'generic_loop_screen',
        visiblePhrases: [
          'This loop may be about checking again.',
          'Another loop moment could be checking relief.',
          'The loop pattern may come back when checking starts.',
        ],
      );

      expect(result.approved, isFalse);
      expect(result.repeatedTerms, isNotEmpty);
      expect(result.repeatedTerms, contains('loop'));
      expect(result.repeatedTerms, contains('checking'));
      expect(result.suggestedFixes, isNotEmpty);
    });

    test('flags generic phrases', () {
      final result = ArchiveCopyRepetitionAudit.checkScreen(
        screenName: 'generic_phrase_screen',
        visiblePhrases: [
          'Something is happening here.',
          'Record another moment when this returns.',
          'Your map is getting sharper.',
        ],
      );

      expect(result.approved, isFalse);
      expect(result.genericPhrases, contains('something is happening'));
      expect(result.genericPhrases, contains('record another moment'));
      expect(result.genericPhrases, contains('your map is getting sharper'));
    });

    test('approves concrete evidence-based copy', () {
      final result = ArchiveCopyRepetitionAudit.checkScreen(
        screenName: 'evidence_screen',
        visiblePhrases: [
          'ArchiveMe has one more piece of evidence.',
          'What changed since your earlier recording.',
          'Record the next time this shows up.',
          'Your words point to pressure before the check.',
        ],
      );

      expect(result.approved, isTrue);
      expect(result.repeatedTerms, isEmpty);
      expect(result.genericPhrases, isEmpty);
    });

    test('flags standalone what changed without evidence context', () {
      final result = ArchiveCopyRepetitionAudit.checkScreen(
        screenName: 'what_changed_screen',
        visiblePhrases: ['What changed', 'What changed'],
      );

      expect(result.approved, isFalse);
      expect(result.genericPhrases, contains('what changed'));
    });

    test('logs audit outcome', () {
      final logs = _captureLogs(() {
        ArchiveCopyRepetitionAudit.checkScreen(
          screenName: 'logged_screen',
          visiblePhrases: ['Record another moment'],
        );
      });

      expect(
        logs.any(
          (l) => l.contains(
            'ARCHIVEME_COPY_REPETITION_AUDIT screen=logged_screen approved=false',
          ),
        ),
        isTrue,
      );
    });

    test('does not introduce diagnostic or therapy language in fixes', () {
      final result = ArchiveCopyRepetitionAudit.checkScreen(
        screenName: 'fix_screen',
        visiblePhrases: [
          'loop loop loop checking checking checking',
          'record another moment',
        ],
      );
      final blob = result.suggestedFixes.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
    });
  });
}