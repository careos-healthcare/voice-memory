import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';

/// Local-only dismissal state for Archive workspace onboarding hints.
abstract final class ArchiveWorkspaceHintStore {
  ArchiveWorkspaceHintStore._();

  static const _prefsKey = 'archive_workspace_hints_dismissed';

  static final Set<String> _dismissed = <String>{};

  static bool isDismissed(String hintId) => _dismissed.contains(hintId);

  static Future<void>? _lastPersist;

  static void dismiss(String hintId) {
    if (hintId.isEmpty) return;
    _dismissed.add(hintId);
    _lastPersist = _persist();
  }

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(_prefsKey);
    if (raw == null) return;
    _dismissed
      ..clear()
      ..addAll((raw['dismissed'] as List<dynamic>? ?? []).whereType<String>());
  }

  static Future<void> _persist() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(_prefsKey, {
      'dismissed': _dismissed.toList()..sort(),
    });
  }

  static Future<void> resetDismissedTips() async {
    _dismissed.clear();
    _lastPersist = _persist();
    await flushForTest();
  }

  @visibleForTesting
  static Future<void> flushForTest() async {
    await (_lastPersist ?? Future<void>.value());
  }

  @visibleForTesting
  static void resetForTest() {
    _dismissed.clear();
    _lastPersist = null;
  }

  @visibleForTesting
  static Set<String> dismissedForTest() => Set.unmodifiable(_dismissed);
}