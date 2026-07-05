import '../first_proof_truth/first_proof_truth_model.dart';

/// Safe action ids for analytics — never transcript or pattern text.
enum FirstProofActionType {
  watchThisNext,
  viewPatternDetails,
  renamePattern,
  keepRecording,
  correctTranscript,
  removeFromPattern,
}

/// Which actions to show after a first proof truth answer.
class FirstProofActionLoopContent {
  const FirstProofActionLoopContent({
    required this.answer,
    required this.title,
    required this.actions,
    this.canShowPatternDetails = false,
    this.canRenamePattern = false,
    this.canCorrectTranscript = false,
    this.canRemoveFromPattern = false,
  });

  final FirstProofTruthAnswer answer;
  final String title;
  final List<FirstProofActionType> actions;
  final bool canShowPatternDetails;
  final bool canRenamePattern;
  final bool canCorrectTranscript;
  final bool canRemoveFromPattern;
}
