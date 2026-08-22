import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';

/// Text-first journaling state — mirrors web pending-reflection mechanics
/// without requiring microphone permission.
enum TextJournalPhase {
  idle,
  composing,
  saving,
  saved,
  error,
}

class TextJournalDraft {
  const TextJournalDraft({
    this.text = '',
    this.promptHint,
    this.phase = TextJournalPhase.idle,
    this.errorMessage,
    this.lastResult,
  });

  final String text;
  final String? promptHint;
  final TextJournalPhase phase;
  final String? errorMessage;
  final CapturePipelineResult? lastResult;

  bool get canSave =>
      phase != TextJournalPhase.saving && text.trim().isNotEmpty;

  TextJournalDraft copyWith({
    String? text,
    String? promptHint,
    TextJournalPhase? phase,
    String? errorMessage,
    CapturePipelineResult? lastResult,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return TextJournalDraft(
      text: text ?? this.text,
      promptHint: promptHint ?? this.promptHint,
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
    );
  }
}

/// Pending reflection placeholder — same shape as web [createPendingReflection].
Reflection createPendingTextReflection() {
  return const Reflection(
    mood: 'quiet',
    emotionalIntensity: 5,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  );
}