import 'dart:io' show Platform;

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

/// Compile-time flag: `flutter test --dart-define=VISUAL_AUDIT=true`
const bool visualAuditFromEnvironment = bool.fromEnvironment(
  'VISUAL_AUDIT',
);

/// Dev-only UI presentation overrides for integration visual audits.
/// Inert unless [active] is true (never in release without the define).
class VisualAuditOverrides {
  VisualAuditOverrides._();

  static bool get active =>
      visualAuditFromEnvironment ||
      (kDebugMode &&
          (Platform.environment.containsKey('FLUTTER_TEST') ||
              visualAuditFromEnvironment));

  static RecordAuditPresentation? recordPresentation;

  static void setRecordPresentation(RecordAuditPresentation? value) {
    recordPresentation = value;
  }

  /// Consumed once per frame build when set.
  static RecordAuditPresentation? peekRecordPresentation() {
    return recordPresentation;
  }
}

/// Snapshot of record screen UI for audit captures.
class RecordAuditPresentation {
  const RecordAuditPresentation({
    required this.ui,
    this.error,
    this.localSaveTitle,
    this.syncNote,
    this.stageLabel,
    this.degradedVoicePostSave = false,
    this.justSavedFirst = false,
    this.entriesAfterSave,
    this.micPhase,
    this.userDeniedThisSession,
    this.lastCaptureAnalysisSucceeded = true,
  });

  final RecordUiState ui;
  final String? error;
  final String? localSaveTitle;
  final String? syncNote;
  final String? stageLabel;
  final bool degradedVoicePostSave;

  /// When true with [entriesAfterSave], simulates first-save post-save UI.
  final bool justSavedFirst;
  final List<JournalEntry>? entriesAfterSave;
  final RecordingPhase? micPhase;
  final bool? userDeniedThisSession;
  final bool lastCaptureAnalysisSucceeded;
}