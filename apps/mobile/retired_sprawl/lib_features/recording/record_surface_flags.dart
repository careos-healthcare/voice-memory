import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show BuildContext;
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:flutter/cupertino.dart' show BuildContext;
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/widgets.dart' show BuildContext;

/// UI-state booleans for record-surface resolution — no [BuildContext].
final class RecordSurfaceFlags {
  const RecordSurfaceFlags({
    required this.ui,
    required this.isIdle,
    required this.isRequestingPermission,
    required this.isPermissionBlocked,
    required this.isReady,
    required this.isRecording,
    required this.isProcessing,
    required this.isDone,
    required this.isError,
  });

  factory RecordSurfaceFlags.from(RecordUiState ui) {
    return RecordSurfaceFlags(
      ui: ui,
      isIdle: ui == RecordUiState.idle,
      isRequestingPermission: ui == RecordUiState.requestingPermission,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isProcessing: ui == RecordUiState.processing,
      isDone: ui == RecordUiState.done,
      isError: ui == RecordUiState.error,
    );
  }

  final RecordUiState ui;
  final bool isIdle;
  final bool isRequestingPermission;
  final bool isPermissionBlocked;
  final bool isReady;
  final bool isRecording;
  final bool isProcessing;
  final bool isDone;
  final bool isError;

  bool get showFraming =>
      isReady ||
      isIdle ||
      isRequestingPermission ||
      isPermissionBlocked;

  bool get canRecord =>
      (isReady || isRecording) &&
      !RecordMicrophonePermissionUi.shouldHideBlockedPanelDuringRequest(ui);

  @override
  bool operator ==(Object other) {
    return other is RecordSurfaceFlags &&
        other.ui == ui &&
        other.isIdle == isIdle &&
        other.isRequestingPermission == isRequestingPermission &&
        other.isPermissionBlocked == isPermissionBlocked &&
        other.isReady == isReady &&
        other.isRecording == isRecording &&
        other.isProcessing == isProcessing &&
        other.isDone == isDone &&
        other.isError == isError;
  }

  @override
  int get hashCode => Object.hash(
    ui,
    isIdle,
    isRequestingPermission,
    isPermissionBlocked,
    isReady,
    isRecording,
    isProcessing,
    isDone,
    isError,
  );
}