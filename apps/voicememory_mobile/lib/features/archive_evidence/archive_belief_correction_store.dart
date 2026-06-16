import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';

/// Lightweight dismissal/save state for archive belief suggestions.
abstract class ArchiveBeliefCorrectionStore {
  ArchiveBeliefCorrectionStore._();

  static const _prefsKey = 'archive_belief_corrections';

  static final Set<String> _sessionDismissed = <String>{};
  static final Set<String> _savedThreads = <String>{};

  static bool isDismissed(String suggestionId) =>
      suggestionId.isEmpty || _sessionDismissed.contains(suggestionId);

  static bool isSaved(String suggestionId) =>
      suggestionId.isNotEmpty && _savedThreads.contains(suggestionId);

  static void dismiss(String suggestionId) {
    if (suggestionId.isEmpty) return;
    _sessionDismissed.add(suggestionId);
    _persist();
  }

  static void markSaved(String suggestionId) {
    if (suggestionId.isEmpty) return;
    _savedThreads.add(suggestionId);
    _sessionDismissed.remove(suggestionId);
    _persist();
  }

  static void applyLoaded({
    required Iterable<String> dismissed,
    required Iterable<String> saved,
  }) {
    _sessionDismissed
      ..clear()
      ..addAll(dismissed);
    _savedThreads
      ..clear()
      ..addAll(saved);
  }

  static Map<String, dynamic> toJson() => {
    'dismissed': _sessionDismissed.toList()..sort(),
    'saved': _savedThreads.toList()..sort(),
  };

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(_prefsKey);
    if (raw == null) return;
    applyLoaded(
      dismissed: (raw['dismissed'] as List<dynamic>? ?? []).whereType<String>(),
      saved: (raw['saved'] as List<dynamic>? ?? []).whereType<String>(),
    );
  }

  static void _persist() {
    if (!AppServices.isInitialized) return;
    // ignore: discarded_futures
    AppServices.instance.prefs.writeMap(_prefsKey, toJson());
  }

  @visibleForTesting
  static void resetForTest() {
    _sessionDismissed.clear();
    _savedThreads.clear();
  }
}
