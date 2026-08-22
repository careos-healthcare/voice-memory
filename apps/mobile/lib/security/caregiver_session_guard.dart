import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Outcome of asking whether the active session may reach an owner-only
/// surface (export, capture, the main app shell).
enum CaregiverAccessDecision {
  /// The owner is driving the app.
  allowed,

  /// A caregiver monitoring session is active.
  deniedCaregiverSession,

  /// The active persona could not be determined. Denied on purpose — see
  /// [CaregiverSessionGuard].
  deniedUnknownSession;

  bool get isAllowed => this == CaregiverAccessDecision.allowed;
}

/// Raised by [CaregiverSessionGuard.assertOwnerAccess] when a surface that
/// belongs to the archive owner is reached from a session that is not theirs.
class CaregiverAccessDeniedException implements Exception {
  const CaregiverAccessDeniedException({
    required this.surface,
    required this.decision,
  });

  final String surface;
  final CaregiverAccessDecision decision;

  @override
  String toString() =>
      'CaregiverAccessDeniedException($surface, ${decision.name})';
}

/// Owner-only gate for surfaces a caregiver session must never reach.
///
/// Caregiver access is read-only and scoped to the streams the owner consented
/// to. Export and capture are neither: an export hands the caregiver the whole
/// archive as a file, and a capture writes into the owner's journal under their
/// name. Neither is covered by the per-stream consent prompt, so neither should
/// be reachable at all while a caregiver session is active.
///
/// The gate lives at the service layer rather than in widget builds, so a new
/// screen cannot reach the data by not knowing about it.
///
/// **Fail closed.** Once caregiver monitoring is compiled in, an active persona
/// that cannot be read is treated as a caregiver, not as the owner. That covers
/// a session persisted by an earlier run that nothing has loaded yet, and a
/// prefs read that throws. With the capability compiled out no caregiver
/// session can exist, so the guard resolves to [CaregiverAccessDecision.allowed]
/// without touching storage.
abstract final class CaregiverSessionGuard {
  CaregiverSessionGuard._();

  /// Owner-only surfaces, named for audit and error messages.
  static const exportAccountPortability = 'export.account_portability';
  static const exportSanitizedArchive = 'export.sanitized_archive';
  static const exportJournalBulk = 'export.journal_bulk';
  static const exportJournalJson = 'export.journal_json';
  static const exportEncryptedBackup = 'export.encrypted_backup';
  static const exportLocalBackup = 'export.local_backup';
  static const exportSelectedEntries = 'export.selected_entries';
  static const captureJournalEntry = 'capture.journal_entry';
  static const playbackRecordingFile = 'playback.recording_file';
  static const playbackTheoryCitation = 'playback.theory_citation';

  /// Test seam for the persona lookup. Returning `null` models the ambiguous
  /// state; throwing models an unreadable one. Both must deny.
  @visibleForTesting
  static Future<AppMode?> Function()? debugModeProbe;

  @visibleForTesting
  static void resetForTest() {
    debugModeProbe = null;
  }

  static Future<CaregiverAccessDecision> evaluate() async {
    if (!CaregiverFeatureFlags.isCaregiverModeEnabled) {
      return CaregiverAccessDecision.allowed;
    }

    final AppMode? mode;
    try {
      mode = await _resolveActiveMode();
      // ignore: silent_catch_audit — an unreadable persona is the ambiguous
      // case the guard exists to deny; the caller surfaces the denial.
    } on Object catch (_) {
      return CaregiverAccessDecision.deniedUnknownSession;
    }

    if (mode == null) return CaregiverAccessDecision.deniedUnknownSession;
    if (mode == AppMode.selfReflection) return CaregiverAccessDecision.allowed;
    return CaregiverAccessDecision.deniedCaregiverSession;
  }

  /// Convenience for callers that only branch on allow/deny.
  static Future<bool> isOwnerSession() async =>
      (await evaluate()).isAllowed;

  /// Throws [CaregiverAccessDeniedException] unless the owner is driving.
  static Future<void> assertOwnerAccess(String surface) async {
    final decision = await evaluate();
    if (decision.isAllowed) return;
    throw CaregiverAccessDeniedException(surface: surface, decision: decision);
  }

  static Future<AppMode?> _resolveActiveMode() async {
    final probe = debugModeProbe;
    if (probe != null) return probe();

    if (CaregiverModeController.isConfigured) {
      final controller = CaregiverModeController.instance;
      await controller.initialize();
      return controller.activeMode;
    }

    // Nothing has loaded the controller in this process. Read the persisted
    // record directly rather than assuming the owner: a caregiver session
    // written by an earlier run is still on this device.
    final state = await CaregiverModeStore(AppServices.instance.prefs).readMode();
    return state.mode;
  }
}
