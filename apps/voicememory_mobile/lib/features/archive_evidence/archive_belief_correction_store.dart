import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';

/// Lightweight dismissal/save state for archive belief suggestions.
abstract class ArchiveBeliefCorrectionStore {
  ArchiveBeliefCorrectionStore._();

  static const _prefsKey = 'archive_belief_corrections';
  static const maxRenamedThreadTitleLength = 120;

  static final Set<String> _sessionDismissed = <String>{};
  static final Set<String> _savedThreads = <String>{};
  static final Map<String, String> _renamedThreadTitles = <String, String>{};

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

  /// Normalizes user-entered thread titles — empty after trim returns null.
  static String? sanitizeRenamedTitle(String raw) => normalizeRenamedTitle(raw);

  @visibleForTesting
  static String? normalizeRenamedTitle(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxRenamedThreadTitleLength) return trimmed;
    return trimmed.substring(0, maxRenamedThreadTitleLength).trimRight();
  }

  static void renameThread(String threadId, String title) {
    if (threadId.isEmpty) return;
    final normalized = normalizeRenamedTitle(title);
    if (normalized == null) return;
    _renamedThreadTitles[threadId] = normalized;
    _persist();
  }

  static String? getRenamedThreadTitle(String threadId) {
    if (threadId.isEmpty) return null;
    return _renamedThreadTitles[threadId];
  }

  static void clearRenamedThreadTitle(String threadId) {
    if (threadId.isEmpty) return;
    if (_renamedThreadTitles.remove(threadId) != null) {
      _persist();
    }
  }

  static String displayThreadTitle({
    required String threadId,
    required String generatedTitle,
  }) => getRenamedThreadTitle(threadId) ?? generatedTitle;

  static void applyLoaded({
    required Iterable<String> dismissed,
    required Iterable<String> saved,
    Map<String, String>? renamed,
  }) {
    _sessionDismissed
      ..clear()
      ..addAll(dismissed);
    _savedThreads
      ..clear()
      ..addAll(saved);
    _renamedThreadTitles
      ..clear()
      ..addAll(renamed ?? const {});
  }

  static Map<String, dynamic> toJson() => {
    'dismissed': _sessionDismissed.toList()..sort(),
    'saved': _savedThreads.toList()..sort(),
    'renamed': Map<String, String>.from(_renamedThreadTitles),
  };

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(_prefsKey);
    if (raw == null) return;
    final renamedRaw = raw['renamed'];
    final renamed = renamedRaw is Map
        ? renamedRaw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : null;
    applyLoaded(
      dismissed: (raw['dismissed'] as List<dynamic>? ?? []).whereType<String>(),
      saved: (raw['saved'] as List<dynamic>? ?? []).whereType<String>(),
      renamed: renamed,
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
    _renamedThreadTitles.clear();
  }
}
