import 'package:archiveme_mobile/features/belief_evidence/evidence/legacy_transcript_registry.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';

/// Why a provenance recovery cannot run right now.
enum ProvenanceRecoveryBlocker {
  /// No saved audio remains for any entry in scope.
  audioMissing,

  /// The on-device-only switch is on, which vetoes remote work outright.
  onDeviceOnly,

  /// Sending recordings for transcription has not been permitted.
  transcriptionNotPermitted,

  /// Both consent conditions are closed.
  onDeviceOnlyAndNotPermitted,
}

/// What a recovery would do, computed before anything is offered to the user.
///
/// Everything the disclosure sheet says is read off this object, so the sheet
/// cannot describe one thing and the action do another.
class ProvenanceRecoveryPlan {
  const ProvenanceRecoveryPlan({
    required this.entryIds,
    required this.recoverableEntryIds,
    required this.needsRemoteProcessing,
    required this.onDeviceProcessingOnly,
    required this.transcriptionPermitted,
  });

  /// Every entry the caller asked about.
  final List<String> entryIds;

  /// The subset that still has audio on this device.
  final List<String> recoverableEntryIds;

  /// Whether the recovery mechanism currently has to leave the device.
  ///
  /// False once transcription can run locally, at which point both consent
  /// conditions stop applying and [canRun] depends on audio alone. The copy is
  /// written so that day needs no rewording.
  final bool needsRemoteProcessing;

  final bool onDeviceProcessingOnly;
  final bool transcriptionPermitted;

  bool get isBulk => entryIds.length > 1;

  bool get hasRecoverableAudio => recoverableEntryIds.isNotEmpty;

  bool get consentSatisfied =>
      !needsRemoteProcessing ||
      (transcriptionPermitted && !onDeviceProcessingOnly);

  bool get canRun => hasRecoverableAudio && consentSatisfied;

  /// The single blocker worth explaining, or null when the action can run.
  ///
  /// Missing audio outranks consent: telling someone to change two settings
  /// for an entry that has no recording left would waste their time.
  ProvenanceRecoveryBlocker? get blocker {
    if (!hasRecoverableAudio) return ProvenanceRecoveryBlocker.audioMissing;
    if (consentSatisfied) return null;
    if (onDeviceProcessingOnly && !transcriptionPermitted) {
      return ProvenanceRecoveryBlocker.onDeviceOnlyAndNotPermitted;
    }
    if (onDeviceProcessingOnly) return ProvenanceRecoveryBlocker.onDeviceOnly;
    return ProvenanceRecoveryBlocker.transcriptionNotPermitted;
  }
}

/// Outcome of a recovery the user asked for.
class ProvenanceRecoveryOutcome {
  const ProvenanceRecoveryOutcome({
    required this.requestedCount,
    required this.recoveredCount,
  });

  const ProvenanceRecoveryOutcome.none() : requestedCount = 0, recoveredCount = 0;

  final int requestedCount;
  final int recoveredCount;

  bool get recoveredAny => recoveredCount > 0;
}

/// The seam between this feature and whatever re-reads the recording.
///
/// Deliberately an interface rather than a direct call into
/// `ProvisionalTranscriptReconciler`. That class is being edited in another
/// workstream, and it does not yet accept these entries anyway: its first
/// guard is `entry.transcriptStatus != TranscriptStatus.provisional`, and a
/// legacy row is `TranscriptStatus.final`. Wiring is therefore deferred, and
/// the adapter that lands later needs to widen that guard to admit
/// `TranscriptProvenance.unknownLegacy` before this port means anything.
///
/// An implementation must not begin work of its own accord. Every method here
/// is reached only from an explicit confirmation.
// A named boundary, not a callback: the whole point is that a reviewer can
// find every implementation of the type that may put a recording on the wire.
// ignore: one_member_abstracts
abstract interface class ProvenanceRecoveryPort {
  /// Re-reads the recording for each entry and re-stamps provenance when the
  /// new reading can be attributed to the user.
  Future<ProvenanceRecoveryOutcome> recover(List<String> entryIds);
}

/// A port that reports honestly that nothing is wired up yet.
///
/// Used as the default so a surface that forgets to inject a real port shows a
/// "could not be recovered" result rather than silently appearing to work.
class UnwiredProvenanceRecoveryPort implements ProvenanceRecoveryPort {
  const UnwiredProvenanceRecoveryPort();

  @override
  Future<ProvenanceRecoveryOutcome> recover(List<String> entryIds) async =>
      ProvenanceRecoveryOutcome(
        requestedCount: entryIds.length,
        recoveredCount: 0,
      );
}

/// Reads the live consent decision for re-transcription.
typedef RemoteTranscriptionConsentReader =
    Future<RemoteProcessingConsentDecision> Function();

/// Builds a [ProvenanceRecoveryPlan] from the registry and the consent gate.
///
/// Consent arrives as a whole [RemoteProcessingConsentDecision] produced by
/// [RemoteProcessingConsentGate], never as two booleans this class recombines.
/// The gate's own documentation is explicit that a call site which recomposes
/// them re-opens the gap between what the switch promises and what the app
/// does, so the seam is drawn where the decision is already made.
class ProvenanceRecoveryPlanner {
  const ProvenanceRecoveryPlanner({
    required this.readConsent,
    this.needsRemoteProcessing = true,
    this.hasAudio = LegacyTranscriptRegistry.hasRecoverableAudio,
  });

  /// Production wiring: the gate answers, this class only reports.
  ProvenanceRecoveryPlanner.fromGate(
    RemoteProcessingConsentGate gate, {
    this.needsRemoteProcessing = true,
    this.hasAudio = LegacyTranscriptRegistry.hasRecoverableAudio,
  }) : readConsent = (() => gate.evaluateFor(
         RemoteProcessingPurpose.remoteTranscription,
       ));

  final RemoteTranscriptionConsentReader readConsent;

  /// False once on-device transcription can do this work.
  final bool needsRemoteProcessing;

  final bool Function(String entryId) hasAudio;

  Future<ProvenanceRecoveryPlan> planFor(List<String> entryIds) async {
    final recoverable = [
      for (final id in entryIds)
        if (hasAudio(id)) id,
    ];

    if (!needsRemoteProcessing) {
      return ProvenanceRecoveryPlan(
        entryIds: entryIds,
        recoverableEntryIds: recoverable,
        needsRemoteProcessing: false,
        onDeviceProcessingOnly: false,
        transcriptionPermitted: true,
      );
    }

    final decision = await readConsent();
    return ProvenanceRecoveryPlan(
      entryIds: entryIds,
      recoverableEntryIds: recoverable,
      needsRemoteProcessing: true,
      onDeviceProcessingOnly: decision.onDeviceProcessingOnly,
      transcriptionPermitted: decision.currentPermission,
    );
  }
}
