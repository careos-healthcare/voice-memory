import '../../features/archive_evidence/archive_evidence.dart';
import '../../features/archive_state_object/archive_state_object.dart';
import '../../models/journal_entry.dart';

enum ArchiveQuestionId {
  why,
  showEvidence,
  showContradictions,
  whenDidThisStart,
  isItGettingStronger,
  whatWouldChangeIt,
  whatChangedRecently,
  howReliableIsIt,
  whereDoesThisAppear,
  strongestEvidence,
}

class ArchiveQuestionAnswer {
  const ArchiveQuestionAnswer({
    required this.questionLabel,
    required this.answerLines,
    this.evidenceLines = const [],
  });

  final String questionLabel;
  final List<String> answerLines;
  final List<String> evidenceLines;
}

class ArchiveQuestionEngine {
  static const headline = 'Question the Archive';

  static const buttonLabels = <ArchiveQuestionId, String>{
    ArchiveQuestionId.why: 'Why?',
    ArchiveQuestionId.showEvidence: 'Show evidence',
    ArchiveQuestionId.showContradictions: 'Show contradictions',
    ArchiveQuestionId.whenDidThisStart: 'When did this start?',
    ArchiveQuestionId.isItGettingStronger: 'Is it getting stronger?',
    ArchiveQuestionId.whatWouldChangeIt: 'What would change its mind?',
    ArchiveQuestionId.whatChangedRecently: 'What changed recently?',
    ArchiveQuestionId.howReliableIsIt: 'How reliable is it?',
    ArchiveQuestionId.whereDoesThisAppear: 'Where does this appear?',
    ArchiveQuestionId.strongestEvidence: 'Strongest evidence',
  };

  static const _insufficientEvidenceAnswer =
      'Not enough reflections with usable transcript detail yet — '
      'the archive will not invent an answer.';

  static ArchiveQuestionAnswer? answer(
    ArchiveQuestionId id, {
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    if (entries.isEmpty || state == null) return null;

    if (!state.hasMinimumEvidence) {
      return ArchiveQuestionAnswer(
        questionLabel: buttonLabels[id] ?? 'Question',
        answerLines: [_insufficientEvidenceAnswer],
      );
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final strongest =
        state.strongestEvidenceQuote ?? archiveStrongestEvidenceQuote(entries);

    switch (id) {
      case ArchiveQuestionId.why:
        return ArchiveQuestionAnswer(
          questionLabel: 'Why does the archive believe this?',
          answerLines: [
            if (state.evidenceSummary != null) state.evidenceSummary!,
            '${eligible.length} reflections with usable transcripts',
          ],
        );
      case ArchiveQuestionId.showEvidence:
        return ArchiveQuestionAnswer(
          questionLabel: 'What evidence supports this belief?',
          answerLines: [
            if (state.evidenceSummary != null)
              state.evidenceSummary!
            else
              _insufficientEvidenceAnswer,
          ],
          evidenceLines: [
            for (final e in eligible.reversed.take(3))
              e.transcript.trim().length > 120
                  ? '${e.transcript.trim().substring(0, 120)}…'
                  : e.transcript.trim(),
          ],
        );
      case ArchiveQuestionId.showContradictions:
        return ArchiveQuestionAnswer(
          questionLabel: 'What contradicts this belief?',
          answerLines: const [
            'No contradicting evidence is stored on this device yet.',
          ],
        );
      case ArchiveQuestionId.whenDidThisStart:
        final first = eligible.first.createdAt.toLocal();
        return ArchiveQuestionAnswer(
          questionLabel: 'When did this belief first appear?',
          answerLines: [
            'Earliest usable reflection: ${first.month}/${first.day}/${first.year}.',
          ],
        );
      case ArchiveQuestionId.isItGettingStronger:
        return ArchiveQuestionAnswer(
          questionLabel: 'Is this belief getting stronger or weaker?',
          answerLines: [state.changeSummary],
        );
      case ArchiveQuestionId.whatWouldChangeIt:
        return ArchiveQuestionAnswer(
          questionLabel: "What would change the archive's mind?",
          answerLines: const [
            'New reflections that do not match patterns in existing transcripts.',
            'Contradicting lines recorded with enough detail to compare.',
          ],
        );
      case ArchiveQuestionId.whatChangedRecently:
        return ArchiveQuestionAnswer(
          questionLabel: 'What changed recently?',
          answerLines: [state.changeSummary],
        );
      case ArchiveQuestionId.howReliableIsIt:
        return ArchiveQuestionAnswer(
          questionLabel: 'How reliable is this belief?',
          answerLines: [
            '${healthLabel(state.health)} — based on ${eligible.length} '
                'reflection${eligible.length == 1 ? '' : 's'} with usable transcripts, '
                'not a confidence score.',
          ],
        );
      case ArchiveQuestionId.whereDoesThisAppear:
        return ArchiveQuestionAnswer(
          questionLabel: 'Where does this belief appear in your life?',
          answerLines: const [
            'Life-area tagging is not available on device yet.',
          ],
        );
      case ArchiveQuestionId.strongestEvidence:
        return ArchiveQuestionAnswer(
          questionLabel: 'What is the strongest evidence?',
          answerLines: [
            if (strongest != null)
              '“$strongest”'
            else
              _insufficientEvidenceAnswer,
          ],
        );
    }
  }
}
