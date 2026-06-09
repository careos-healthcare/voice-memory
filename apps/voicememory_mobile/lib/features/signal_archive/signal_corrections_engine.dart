import '../post_save_insight/selected_signal_model.dart';
import '../post_save_insight/signal_feedback_model.dart';
import 'signal_corrections_model.dart';

/// Derives correction memory from local signal feedback — no shame, no "AI learned".
class SignalCorrectionsEngine {
  const SignalCorrectionsEngine();

  SignalCorrectionView build({
    required List<PostSaveSignalFeedback> feedback,
    required SelectedSignalRecord? currentSignal,
  }) {
    final rejected = <String>[];
    final seen = <String>{};

    for (final row in feedback) {
      if (row.action != PostSaveSignalAction.rejected &&
          row.action != PostSaveSignalAction.abChoiceNeither) {
        continue;
      }
      final title = row.signalTitle.trim();
      if (title.isEmpty || seen.contains(title)) continue;
      seen.add(title);
      rejected.add(title);
    }

    String? selectedAlt;
    if (currentSignal != null && currentSignal.title.trim().isNotEmpty) {
      final acceptedCurrent = feedback.any(
        (f) =>
            f.action == PostSaveSignalAction.accepted &&
            f.signalTitle == currentSignal.title,
      );
      if (acceptedCurrent || rejected.isNotEmpty) {
        selectedAlt = currentSignal.title;
      }
    }

    return SignalCorrectionView(
      rejectedTitles: rejected,
      selectedAlternativeTitle: selectedAlt,
      hasCorrections: rejected.isNotEmpty || selectedAlt != null,
    );
  }
}
