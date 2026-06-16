import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_explanations/explanation_models.dart';

/// One specific, evidence-grounded follow-up — never generic assistant chat.
class ArchiveFollowupQuestionEngine {
  const ArchiveFollowupQuestionEngine();

  String generate({
    required ArchiveInsightRef ref,
    required ArchiveExplanation explanation,
    required List<JournalEntry> entries,
  }) {
    final belief = explanation.beliefStatement?.trim();
    final themeKey = ref.themeKey;
    final themeName = explanation.relatedThemes.isNotEmpty
        ? explanation.relatedThemes.first.name
        : themeKey;

    return switch (ref.kind) {
      ArchiveInsightKind.contradiction =>
        'What would someone close to you say about both sides of this tension?',
      ArchiveInsightKind.theme =>
        'When do you mention ${themeName ?? themeKey ?? 'this theme'} least strongly in a typical week?',
      ArchiveInsightKind.beliefChange || ArchiveInsightKind.belief =>
        belief != null && belief.length > 12
            ? 'What happened immediately before “${_short(belief, 48)}” showed up in a recording?'
            : 'What happened immediately before this pattern appeared in your archive?',
      ArchiveInsightKind.chapter =>
        'What detail from this chapter would you want the archive to weigh more heavily?',
      ArchiveInsightKind.surprise => _emotionOrSurpriseQuestion(
        entries,
        explanation,
      ),
      ArchiveInsightKind.challenge =>
        'What recording would most clearly show whether the archive should keep this challenge open?',
      ArchiveInsightKind.blindSpot =>
        'When do you notice this blind spot least — and what were you doing then?',
      ArchiveInsightKind.askArchive =>
        explanation.whySummary.length > 20
            ? 'What would a follow-up recording add to: “${_short(explanation.whySummary, 56)}”?'
            : 'What would one more recording clarify about this answer?',
      ArchiveInsightKind.weeklyStory =>
        'Which moment this week best represents the story your archive is telling?',
    };
  }

  String _emotionOrSurpriseQuestion(
    List<JournalEntry> entries,
    ArchiveExplanation explanation,
  ) {
    final recent = archiveEligibleEvidenceEntries(entries);
    if (recent.length >= 2) {
      final latest = recent.last;
      final prior = recent[recent.length - 2];
      if (latest.reflection.emotionalIntensity >
          prior.reflection.emotionalIntensity + 1) {
        return 'What happened on the day before your most intense recent reflection?';
      }
      if (latest.reflection.emotionalIntensity <
          prior.reflection.emotionalIntensity - 1) {
        return 'When do you feel this pattern least strongly in your day?';
      }
    }
    if (explanation.supportingEvidence.isNotEmpty) {
      return 'What would you add to the reflection from '
          '${_monthDay(explanation.supportingEvidence.last.recordedAt)}?';
    }
    return 'What would one more recording reveal about this shift?';
  }

  static String _short(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static String _monthDay(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
