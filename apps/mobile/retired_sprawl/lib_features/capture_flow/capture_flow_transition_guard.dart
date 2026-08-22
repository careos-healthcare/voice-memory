import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';

/// Validates capture state transitions — illegal moves fail closed.
abstract final class CaptureFlowTransitionGuard {
  CaptureFlowTransitionGuard._();

  static const _allowed = {
    CaptureFlowPhase.ready: {
      CaptureFlowPhase.requestingPermission,
      CaptureFlowPhase.savingLocal,
      CaptureFlowPhase.recoverableFailure,
    },
    CaptureFlowPhase.requestingPermission: {
      CaptureFlowPhase.ready,
      CaptureFlowPhase.recording,
      CaptureFlowPhase.recoverableFailure,
    },
    CaptureFlowPhase.recording: {
      CaptureFlowPhase.ready,
      CaptureFlowPhase.stopping,
      CaptureFlowPhase.recoverableFailure,
    },
    CaptureFlowPhase.stopping: {
      CaptureFlowPhase.savingLocal,
      CaptureFlowPhase.ready,
      CaptureFlowPhase.recoverableFailure,
    },
    CaptureFlowPhase.savingLocal: {
      CaptureFlowPhase.savedLocal,
      CaptureFlowPhase.processingRemote,
      CaptureFlowPhase.savedWithReflection,
      CaptureFlowPhase.recoverableFailure,
    },
    CaptureFlowPhase.savedLocal: {
      CaptureFlowPhase.processingRemote,
      CaptureFlowPhase.savedWithReflection,
      CaptureFlowPhase.ready,
      CaptureFlowPhase.recoverableFailure,
    },
    CaptureFlowPhase.processingRemote: {
      CaptureFlowPhase.savedWithReflection,
      CaptureFlowPhase.savedLocal,
      CaptureFlowPhase.recoverableFailure,
    },
    CaptureFlowPhase.savedWithReflection: {
      CaptureFlowPhase.ready,
      CaptureFlowPhase.processingRemote,
    },
    CaptureFlowPhase.recoverableFailure: {
      CaptureFlowPhase.ready,
      CaptureFlowPhase.savingLocal,
      CaptureFlowPhase.processingRemote,
    },
  };

  static bool canTransition(CaptureFlowPhase from, CaptureFlowPhase to) =>
      from == to || (_allowed[from]?.contains(to) ?? false);
}
