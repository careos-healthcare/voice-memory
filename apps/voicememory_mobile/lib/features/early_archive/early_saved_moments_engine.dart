import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import 'early_repeat_progress_model.dart';
import 'early_saved_moments_copy.dart';
import 'early_saved_moments_model.dart';

/// Builds the early saved-moments review sheet from local journal entries.
abstract final class EarlySavedMomentsEngine {
  EarlySavedMomentsEngine._();

  static const _previewMaxChars = 120;

  static EarlySavedMomentsSheetContent? build({
    required List<JournalEntry> entries,
    required EarlyRepeatProgressResult progress,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty || eligible.length > 2) return null;

    final moments = [
      for (var i = 0; i < eligible.length; i++)
        EarlySavedMomentPreview(
          index: i + 1,
          label: '${EarlySavedMomentsCopy.momentLabelPrefix} ${i + 1}',
          previewText: _previewText(eligible[i]),
          savedAt: eligible[i].createdAt,
        ),
    ];

    final hasConfirmedRepeat = progress.claimsRepeatForming;
    final hasNoClearMatch =
        progress.kind == EarlyRepeatProgressKind.twoUnrelated;

    return EarlySavedMomentsSheetContent(
      moments: moments,
      comparisonBody: _comparisonBody(progress.kind),
      nextActionBody: _nextActionBody(progress.kind),
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasNoClearMatch: hasNoClearMatch,
    );
  }

  static String? _comparisonBody(EarlyRepeatProgressKind kind) {
    return switch (kind) {
      EarlyRepeatProgressKind.oneMoment => null,
      EarlyRepeatProgressKind.twoRelated =>
        EarlySavedMomentsCopy.comparingRelated,
      EarlyRepeatProgressKind.twoUnrelated =>
        EarlySavedMomentsCopy.comparingNoClearMatch,
    };
  }

  static String _nextActionBody(EarlyRepeatProgressKind kind) {
    return switch (kind) {
      EarlyRepeatProgressKind.oneMoment =>
        EarlySavedMomentsCopy.nextActionOneEntry,
      EarlyRepeatProgressKind.twoUnrelated =>
        EarlySavedMomentsCopy.nextActionTwoUnrelated,
      EarlyRepeatProgressKind.twoRelated =>
        EarlySavedMomentsCopy.nextActionTwoRelated,
    };
  }

  static String _previewText(JournalEntry entry) {
    final summary = entry.reflectionSummary.trim();
    if (summary.length >= 12) {
      return _truncate(summary);
    }
    final transcript = entry.transcript.trim();
    if (transcript.length >= ArchiveEvidenceGuard.minimumTranscriptChars) {
      return _truncate(transcript);
    }
    return '';
  }

  static String _truncate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _previewMaxChars) return cleaned;
    return '${cleaned.substring(0, _previewMaxChars - 1).trim()}…';
  }
}
