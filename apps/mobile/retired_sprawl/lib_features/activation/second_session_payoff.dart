import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// User-facing copy for the second saved moment payoff.
abstract final class SecondSessionPayoffCopy {
  static const String title = VisibleArchiveProofCopy.twoEntryCompareTitle;

  static const String bodyUngrounded = VisibleArchiveProofCopy.twoEntryBodyUngrounded;

  static const String bodyGrounded = VisibleArchiveProofCopy.twoEntryBodyGrounded;

  static const String primaryCta = VisibleArchiveProofCopy.twoEntryPrimaryCta;

  static const String secondaryCta = VisibleArchiveProofCopy.twoEntryViewArchiveCta;

  static const String analysisDeferredFootnote =
      VoiceCaptureCopy.analysisUnavailableNote;
}

/// Cautious payoff when the archive reaches exactly two usable moments.
class SecondSessionPayoff {
  const SecondSessionPayoff({
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.hasGroundedMatch,
    this.footnoteLine,
  });

  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final bool hasGroundedMatch;
  final String? footnoteLine;
}

/// Deterministic second-session payoff — no invented patterns.
abstract final class SecondSessionPayoffEngine {
  SecondSessionPayoffEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  /// Returns null unless exactly two eligible entries exist.
  static SecondSessionPayoff? build({
    required List<JournalEntry> entries,
    bool analysisSucceeded = true,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 2) return null;

    final grounded = _signalEngine.hasGroundedRepeatMatch(eligible);
    return SecondSessionPayoff(
      title: SecondSessionPayoffCopy.title,
      body: grounded
          ? SecondSessionPayoffCopy.bodyGrounded
          : SecondSessionPayoffCopy.bodyUngrounded,
      primaryCta: SecondSessionPayoffCopy.primaryCta,
      secondaryCta: SecondSessionPayoffCopy.secondaryCta,
      hasGroundedMatch: grounded,
      footnoteLine: analysisSucceeded
          ? null
          : SecondSessionPayoffCopy.analysisDeferredFootnote,
    );
  }
}