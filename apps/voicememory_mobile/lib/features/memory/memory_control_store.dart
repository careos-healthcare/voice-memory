import 'package:flutter/foundation.dart';

import 'memory_control_model.dart';

/// Session-scoped "Not related" suppression for individual memory cards.
///
/// Marking a card "Not related" hides that specific suggested connection
/// for the current app session only. Nothing is deleted, archive history
/// is not rewritten, other cards keep working, and memory stays on for
/// future entries.
abstract class MemoryControlStore {
  MemoryControlStore._();

  static final Set<String> _notRelatedThisSession = <String>{};

  static void markNotRelated(MemoryCardType type) {
    _notRelatedThisSession.add(type.id);
  }

  static bool isSuppressed(MemoryCardType type) =>
      _notRelatedThisSession.contains(type.id);

  @visibleForTesting
  static void resetSessionForTest() {
    _notRelatedThisSession.clear();
  }
}
