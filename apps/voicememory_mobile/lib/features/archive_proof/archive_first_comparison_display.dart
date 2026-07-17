import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import 'visible_archive_proof_copy.dart';

/// User-facing Archive first-comparison card — existing engines only.
class ArchiveFirstComparisonDisplay {
  const ArchiveFirstComparisonDisplay({
    required this.show,
    required this.title,
    required this.body,
    this.evidenceLine,
    this.whatChangedLine,
    required this.primaryIsViewEvidence,
    required this.hasGroundedPattern,
  });

  const ArchiveFirstComparisonDisplay.hidden()
      : show = false,
        title = '',
        body = '',
        evidenceLine = null,
        whatChangedLine = null,
        primaryIsViewEvidence = false,
        hasGroundedPattern = false;

  final bool show;
  final String title;
  final String body;
  final String? evidenceLine;
  final String? whatChangedLine;
  final bool primaryIsViewEvidence;
  final bool hasGroundedPattern;

  static ArchiveFirstComparisonDisplay resolve(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 2) return const ArchiveFirstComparisonDisplay.hidden();

    const signalEngine = SecondSessionSignalEngine();
    final comparison = signalEngine.build(entries);
    final grounded = signalEngine.hasGroundedRepeatMatch(entries);

    if (grounded) {
      final evidence = _usableLine(comparison.whatRepeated);
      final changed = _usableLine(comparison.whatChanged);
      final body = evidence == null
          ? VisibleArchiveProofCopy.archiveFirstComparisonCautionThin
          : (evidence.toLowerCase().contains('mentioned') ||
                  evidence.toLowerCase().contains('similar'))
              ? VisibleArchiveProofCopy.archiveFirstComparisonMentionedBefore
              : VisibleArchiveProofCopy.archiveFirstComparisonMayConnectBody;
      return ArchiveFirstComparisonDisplay(
        show: true,
        title: VisibleArchiveProofCopy.archiveFirstComparisonTitle,
        body: body,
        evidenceLine: evidence,
        whatChangedLine: changed,
        primaryIsViewEvidence: true,
        hasGroundedPattern: true,
      );
    }

    return ArchiveFirstComparisonDisplay(
      show: true,
      title: VisibleArchiveProofCopy.twoEntryCompareTitle,
      body: VisibleArchiveProofCopy.twoEntryBodyUngrounded,
      evidenceLine: null,
      whatChangedLine: null,
      primaryIsViewEvidence: false,
      hasGroundedPattern: false,
    );
  }

  static String? _usableLine(String? line) {
    final trimmed = line?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed == ConsumerUiCopy.secondSessionFallbackWhatRepeated) {
      return null;
    }
    if (trimmed == ConsumerUiCopy.secondSessionFallbackWhatChanged) {
      return null;
    }
    return trimmed;
  }
}
