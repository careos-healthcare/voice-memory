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

  static const _signalEngine = SecondSessionSignalEngine();

  static ArchiveFirstComparisonDisplay resolve(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 2)
      return const ArchiveFirstComparisonDisplay.hidden();

    final comparison = _signalEngine.build(entries);
    if (!comparison.hasEnoughData) {
      return const ArchiveFirstComparisonDisplay.hidden();
    }

    if (!comparison.possibleRepeat) {
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

    final thread = _usableLine(comparison.whatRepeated);
    if (thread == null) {
      return ArchiveFirstComparisonDisplay(
        show: true,
        title: VisibleArchiveProofCopy.archiveFirstComparisonTitle,
        body: VisibleArchiveProofCopy.archiveFirstComparisonCautionThin,
        evidenceLine: null,
        whatChangedLine: null,
        primaryIsViewEvidence: true,
        hasGroundedPattern: false,
      );
    }

    final change =
        _usableLine(comparison.whatChanged) ??
        'ArchiveMe is still comparing your saved words.';

    return ArchiveFirstComparisonDisplay(
      show: true,
      title: VisibleArchiveProofCopy.archiveFirstComparisonTitle,
      body: VisibleArchiveProofCopy.archiveFirstComparisonConnectBody(
        thread: thread,
        change: change,
      ),
      evidenceLine: null,
      whatChangedLine: null,
      primaryIsViewEvidence: true,
      hasGroundedPattern: true,
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
