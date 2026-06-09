import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../screens/record_screen.dart';

/// Compile-time flag: `flutter test --dart-define=VISUAL_AUDIT=true`
const bool visualAuditFromEnvironment =
    bool.fromEnvironment('VISUAL_AUDIT', defaultValue: false);

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
  });

  final RecordUiState ui;
  final String? error;
  final String? localSaveTitle;
  final String? syncNote;
  final String? stageLabel;
}
