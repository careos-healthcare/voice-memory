import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/low_evidence/low_evidence_copy.dart';
import 'package:archiveme_mobile/features/low_evidence/low_evidence_model.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Classifies low-evidence archive states using existing quality gates only.
abstract final class LowEvidenceEngine {
  LowEvidenceEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static bool _onlyQuietDayEntries(List<JournalEntry> entries) {
    final withText = entries
        .map(ComparableEvidenceText.userText)
        .where((text) => text.trim().isNotEmpty)
        .toList();
    if (withText.isEmpty) return false;
    return withText.every(RecordCaptureModeEngine.isQuietDayText);
  }

  static LowEvidenceGuidance? buildForRecordReady({
    required List<JournalEntry> entries,
  }) {
    if (entries.isEmpty) return null;
    if (ArchiveEvidenceQualityGate.allowsFirstProof(entries)) return null;

    return _build(entries);
  }

  static LowEvidenceGuidance? buildForPatternsTab({
    required List<JournalEntry> entries,
  }) {
    if (entries.isEmpty) return null;
    if (ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) return null;

    return _build(entries);
  }

  static LowEvidenceGuidance? _build(List<JournalEntry> entries) {
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return const LowEvidenceGuidance(
        kind: LowEvidenceStateKind.genericTestOnly,
        title: LowEvidenceCopy.genericTestTitle,
        body: LowEvidenceCopy.genericTestBody,
      );
    }

    if (_onlyQuietDayEntries(entries)) {
      return const LowEvidenceGuidance(
        kind: LowEvidenceStateKind.quietDayOnly,
        title: LowEvidenceCopy.quietDayTitle,
        body: LowEvidenceCopy.quietDayBody,
      );
    }

    final usable = ArchiveEvidenceQualityGate.usableEntries(entries);
    if (usable.isEmpty) return null;

    if (usable.length == 1) {
      return const LowEvidenceGuidance(
        kind: LowEvidenceStateKind.oneRealEntry,
        title: LowEvidenceCopy.oneEntryTitle,
        body: LowEvidenceCopy.oneEntryBody,
      );
    }

    if (usable.length == 2) {
      if (_signalEngine.hasGroundedRepeatMatch(usable)) {
        return const LowEvidenceGuidance(
          kind: LowEvidenceStateKind.twoRelatedNotEnough,
          title: LowEvidenceCopy.twoRelatedTitle,
          body: LowEvidenceCopy.twoRelatedBody,
          claimsRepeatForming: true,
        );
      }
      return const LowEvidenceGuidance(
        kind: LowEvidenceStateKind.twoUnrelatedRealEntries,
        title: LowEvidenceCopy.twoUnrelatedTitle,
        body: LowEvidenceCopy.twoUnrelatedBody,
      );
    }

    return null;
  }
}