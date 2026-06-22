import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import 'voice_capture_quality.dart';

/// User-facing copy when transcription succeeded but backend analysis failed.
abstract final class AnalysisFallbackPayoffCopy {
  static const title = 'ArchiveMe saved what you said.';

  static const bodyOneEntry =
      'Analysis is not available right now, but this moment is still in your '
      'archive.';

  static const bodyTwoEntries =
      'Analysis is not available right now, but both moments are still in '
      'your archive.';

  static const bodyManyEntries =
      'Analysis is not available right now, but your moments are still in '
      'your archive.';

  static const evidenceOneEntry =
      'One piece of evidence saved from your own words.';

  static const evidenceTwoEntries =
      'ArchiveMe has two moments to compare.';

  static const evidenceTwoEntriesOverlap =
      'Some of your own words appear in both moments.';

  static const noClearRepeatYet = 'No clear repeat yet.';

  static const nextActionOneEntry =
      'Add one more moment when this comes up again.';

  static const nextActionTwoEntries =
      'Add one more moment when this comes up again.';

  static const deferredFootnote =
      'Deeper analysis can run later. This moment is already saved.';
}

/// Cautious local payoff when analysis is unavailable but transcript exists.
class AnalysisFallbackPayoff {
  const AnalysisFallbackPayoff({
    required this.title,
    required this.body,
    required this.evidenceLine,
    required this.nextActionLine,
    this.secondaryLine,
    required this.footnoteLine,
  });

  final String title;
  final String body;
  final String evidenceLine;
  final String nextActionLine;
  final String? secondaryLine;
  final String footnoteLine;
}

/// Deterministic, offline payoff — never claims AI insight or patterns.
abstract final class AnalysisFallbackPayoffEngine {
  AnalysisFallbackPayoffEngine._();

  /// Returns null when analysis succeeded, transcript is unusable, or entry
  /// is a degraded voice capture awaiting typed recovery.
  static AnalysisFallbackPayoff? build({
    required List<JournalEntry> entries,
    required bool analysisSucceeded,
  }) {
    if (analysisSucceeded) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    final latest = eligible.last;
    if (VoiceCaptureQuality.isDegradedVoiceCapture(latest)) return null;
    if (!VoiceCaptureQuality.hasUsableSpokenText(latest)) return null;

    final count = eligible.length;
    if (count == 2 || count == 3) return null;

    if (count == 1) {
      return const AnalysisFallbackPayoff(
        title: AnalysisFallbackPayoffCopy.title,
        body: AnalysisFallbackPayoffCopy.bodyOneEntry,
        evidenceLine: AnalysisFallbackPayoffCopy.evidenceOneEntry,
        nextActionLine: AnalysisFallbackPayoffCopy.nextActionOneEntry,
        footnoteLine: AnalysisFallbackPayoffCopy.deferredFootnote,
      );
    }

    return const AnalysisFallbackPayoff(
      title: AnalysisFallbackPayoffCopy.title,
      body: AnalysisFallbackPayoffCopy.bodyManyEntries,
      evidenceLine: VisibleArchiveProofCopy.earlyRepeatEvidenceLine,
      nextActionLine: AnalysisFallbackPayoffCopy.nextActionTwoEntries,
      footnoteLine: AnalysisFallbackPayoffCopy.deferredFootnote,
    );
  }
}
