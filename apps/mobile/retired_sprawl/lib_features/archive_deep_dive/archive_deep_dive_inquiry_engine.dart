import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_models.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';

/// Evidence-based self-inquiry prompts — template only, no AI.
class ArchiveDeepDiveInquiryEngine {
  const ArchiveDeepDiveInquiryEngine();

  List<ArchiveDeepDiveInquiryQuestion> build({
    required ArchiveV1View v1,
    required bool hasDistinctEvolution,
    required bool hasContradictions,
    required bool beliefWeakening,
    DateTime? firstEvidenceAt,
  }) {
    final questions = <ArchiveDeepDiveInquiryQuestion>[];
    final belief = v1.belief?.statement.trim() ?? '';

    questions.add(
      ArchiveDeepDiveInquiryQuestion(
        id: 'if_false',
        prompt: 'What would happen if this belief was false?',
        rationale: belief.isNotEmpty
            ? 'Grounded in your stated belief: “${_truncate(belief, 80)}”.'
            : 'Grounded in your current archive belief.',
      ),
    );

    if (firstEvidenceAt != null) {
      questions.add(
        const ArchiveDeepDiveInquiryQuestion(
          id: 'first_appearance',
          prompt: 'When did this pattern first appear?',
          rationale:
              'Your earliest eligible recording is on the timeline below.',
        ),
      );
    }

    if (hasContradictions) {
      questions.add(
        const ArchiveDeepDiveInquiryQuestion(
          id: 'against',
          prompt: 'What evidence argues against it?',
          rationale: 'The archive surfaced contradictions tied to this belief.',
        ),
      );
    }

    if (hasDistinctEvolution || beliefWeakening) {
      questions.add(
        ArchiveDeepDiveInquiryQuestion(
          id: 'weakened',
          prompt: 'What changed when this belief weakened?',
          rationale: hasDistinctEvolution
              ? 'THEN and NOW beliefs differ in your evolution timeline.'
              : 'Recent recordings show lower overlap with this belief.',
        ),
      );
    }

    if (v1.blindSpots.isNotEmpty) {
      questions.add(
        ArchiveDeepDiveInquiryQuestion(
          id: 'blind_spot',
          prompt: 'What might you be saying often without noticing?',
          rationale:
              'Connected blind spot: “${_truncate(v1.blindSpots.first.headline, 72)}”.',
        ),
      );
    }

    return questions.take(5).toList();
  }

  String _truncate(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }
}