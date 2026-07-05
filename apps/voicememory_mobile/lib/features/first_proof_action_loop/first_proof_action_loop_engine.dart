import '../../models/journal_entry.dart';
import '../archive_controls/archive_exclusion_engine.dart';
import '../first_proof_payoff/first_proof_payoff_model.dart';
import '../first_proof_truth/first_proof_truth_model.dart';
import '../pattern_naming/pattern_name_engine.dart';
import '../transcript_correction/transcript_correction_gate.dart';
import 'first_proof_action_loop_copy.dart';
import 'first_proof_action_loop_model.dart';

/// Builds first proof action loop content from truth answer and entries.
abstract final class FirstProofActionLoopEngine {
  FirstProofActionLoopEngine._();

  static FirstProofActionLoopContent? build({
    required FirstProofTruthAnswer answer,
    required List<JournalEntry> entries,
    required FirstProofPayoff payoff,
  }) {
    final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(entries);
    final patternPrompt = PatternNameEngine.buildPrompt(entries: entries);
    final latestEntry = entries.isNotEmpty ? entries.last : null;
    final canCorrectTranscript = latestEntry != null &&
        TranscriptCorrectionGate.entryAllowsCorrection(latestEntry);
    final canRemoveFromPattern =
        patternKey != null && latestEntry != null && latestEntry.id.isNotEmpty;
    final canRenamePattern =
        patternPrompt != null || (patternKey != null && payoff.groundedPhrase.isNotEmpty);
    final canShowPatternDetails = payoff.canShowPatternDetail;

    return switch (answer) {
      FirstProofTruthAnswer.yes => FirstProofActionLoopContent(
          answer: answer,
          title: FirstProofActionLoopCopy.yesTitle,
          actions: [
            FirstProofActionType.watchThisNext,
            if (canShowPatternDetails) FirstProofActionType.viewPatternDetails,
          ],
          canShowPatternDetails: canShowPatternDetails,
        ),
      FirstProofTruthAnswer.sortOf => FirstProofActionLoopContent(
          answer: answer,
          title: FirstProofActionLoopCopy.sortOfTitle,
          actions: [
            if (canRenamePattern) FirstProofActionType.renamePattern,
            FirstProofActionType.keepRecording,
          ],
          canRenamePattern: canRenamePattern,
        ),
      FirstProofTruthAnswer.no => FirstProofActionLoopContent(
          answer: answer,
          title: FirstProofActionLoopCopy.noTitle,
          actions: [
            if (canCorrectTranscript) FirstProofActionType.correctTranscript,
            if (canRemoveFromPattern) FirstProofActionType.removeFromPattern,
            FirstProofActionType.keepRecording,
          ],
          canCorrectTranscript: canCorrectTranscript,
          canRemoveFromPattern: canRemoveFromPattern,
        ),
    };
  }
}
