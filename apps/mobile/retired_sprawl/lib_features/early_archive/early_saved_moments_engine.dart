import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/early_archive/early_repeat_progress_model.dart';
import 'package:archiveme_mobile/features/early_archive/early_saved_moments_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_saved_moments_model.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_gate.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the early saved-moments review sheet from local journal entries.
abstract final class EarlySavedMomentsEngine {
  EarlySavedMomentsEngine._();

  static const _previewMaxChars = 120;

  static EarlySavedMomentsSheetContent? build({
    required List<JournalEntry> entries,
    required EarlyRepeatProgressResult progress,
  }) {
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.isEmpty || sorted.length > 2) return null;

    final moments = [
      for (var i = 0; i < sorted.length; i++)
        EarlySavedMomentPreview(
          index: i + 1,
          label: '${EarlySavedMomentsCopy.momentLabelPrefix} ${i + 1}',
          previewText: _previewText(sorted[i]),
          savedAt: sorted[i].createdAt,
          entryId: sorted[i].id,
          isPendingTranscript: PendingTranscriptRecoveryGate.entryNeedsRecovery(
            sorted[i],
          ),
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
    if (PendingTranscriptRecoveryGate.entryNeedsRecovery(entry)) {
      return PendingTranscriptRecoveryCopy.body;
    }
    final text = ComparableEvidenceText.userText(entry);
    if (text.length >= ArchiveEvidenceGuard.minimumTranscriptChars) {
      return _truncate(text);
    }
    return '';
  }

  static String _truncate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _previewMaxChars) return cleaned;
    return '${cleaned.substring(0, _previewMaxChars - 1).trim()}…';
  }
}