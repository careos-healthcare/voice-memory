import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';

/// Proof relevance repair copy — clearer proof wording, no journal text.
abstract final class ProofRelevanceRepairCopy {
  ProofRelevanceRepairCopy._();

  static const strongLead = 'ArchiveMe noticed this repeated:';
  static const softerLead = 'ArchiveMe may be noticing this:';

  static const whyAppearedPrefix = 'Why this appeared:';
  static const whyAppearedBody = 'similar moments mention this same behaviour.';

  static String get whyAppearedLine => '$whyAppearedPrefix $whyAppearedBody';

  static const relevanceQuestion = 'Does this feel accurate?';

  static const answerYes = 'Yes';
  static const answerTooVague = 'Too vague';
  static const answerNotRelevant = 'Not relevant';

  static const tooVagueResponse =
      'Got it. ArchiveMe will wait for more specific evidence before showing this again.';

  static const notRelevantResponse =
      'Got it. ArchiveMe will not treat this as useful proof.';

  static const List<BetaProofFeedbackType> relevanceFeedbackTypes = [
    BetaProofFeedbackType.useful,
    BetaProofFeedbackType.tooVague,
    BetaProofFeedbackType.notRelevant,
  ];

  static const bannedRelevancePhrases = [
    'this is your pattern',
    'recurring theme',
    'therapy',
    'diagnosis',
    'coach',
    'coaching',
    'you should',
    'you need to',
  ];

  static String formatBehaviorPhrase(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) return trimmed;
    return '"$trimmed"';
  }

  static String labelFor(BetaProofFeedbackType type) => switch (type) {
    BetaProofFeedbackType.useful => answerYes,
    BetaProofFeedbackType.tooVague => answerTooVague,
    BetaProofFeedbackType.alreadyKnew => answerYes,
    BetaProofFeedbackType.notRelevant => answerNotRelevant,
  };

  static String responseFor(BetaProofFeedbackType type) => switch (type) {
    BetaProofFeedbackType.tooVague => tooVagueResponse,
    BetaProofFeedbackType.notRelevant => notRelevantResponse,
    _ => 'Thanks — this helps tune what ArchiveMe shows next.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield strongLead;
    yield softerLead;
    yield whyAppearedLine;
    yield relevanceQuestion;
    yield answerYes;
    yield answerTooVague;
    yield answerNotRelevant;
    yield tooVagueResponse;
    yield notRelevantResponse;
    for (final type in relevanceFeedbackTypes) {
      yield labelFor(type);
      yield responseFor(type);
    }
  }
}