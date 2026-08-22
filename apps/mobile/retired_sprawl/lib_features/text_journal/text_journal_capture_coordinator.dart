import 'package:archiveme_mobile/features/text_journal/text_journal_state.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';

/// Coordinates typed capture without microphone permission.
class TextJournalCaptureCoordinator {
  TextJournalCaptureCoordinator(this._pipeline);

  final CapturePipelineService _pipeline;

  TextJournalDraft _draft = const TextJournalDraft();

  TextJournalDraft get draft => _draft;

  void begin({String? promptHint}) {
    _draft = TextJournalDraft(
      phase: TextJournalPhase.composing,
      promptHint: promptHint,
    );
  }

  void updateText(String text) {
    _draft = _draft.copyWith(
      text: text,
      phase: TextJournalPhase.composing,
      clearError: true,
    );
  }

  void reset() {
    _draft = const TextJournalDraft();
  }

  Future<CapturePipelineResult?> save({
    ImageEvidence? imageEvidence,
  }) async {
    final trimmed = _draft.text.trim();
    if (trimmed.isEmpty) {
      _draft = _draft.copyWith(
        phase: TextJournalPhase.error,
        errorMessage: 'Enter a thought before saving.',
      );
      return null;
    }

    _draft = _draft.copyWith(phase: TextJournalPhase.saving, clearError: true);
    try {
      final outcome = imageEvidence != null
          ? await _pipeline.saveImageCaptionEntry(
              caption: trimmed,
              imageEvidence: imageEvidence,
            )
          : await _pipeline.saveTextThought(transcript: trimmed);
      final result = outcome.getOrThrow();
      _draft = _draft.copyWith(
        phase: TextJournalPhase.saved,
        lastResult: result,
      );
      return result;
    } on CapturePipelineFailure catch (e, stackTrace) {
      _draft = _draft.copyWith(
        phase: TextJournalPhase.error,
        errorMessage: e.message,
      );
      return null;
    } catch (_, stackTrace) {
      _draft = _draft.copyWith(
        phase: TextJournalPhase.error,
        errorMessage: 'Could not save your thought. Try again.',
      );
      return null;
    }
  }
}

/// Whether an entry was saved as typed text (no audio required).
bool isTextCaptureEntry(JournalEntry entry) =>
    entry.captureSource == 'text' ||
    entry.captureSource == 'image_caption' ||
    (entry.localAudioPath == null && entry.durationSeconds == 0);