import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'entry_memory_mode.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// How the user wants to assign a thread for the next save.
enum EntryThreadScope {
  noThread('no_thread'),
  existingThread('existing_thread'),
  newThread('new_thread');

  const EntryThreadScope(this.id);

  final String id;

  String get label => switch (this) {
    EntryThreadScope.noThread => EntryThreadScopeCopy.noThreadLabel,
    EntryThreadScope.existingThread => EntryThreadScopeCopy.existingThreadLabel,
    EntryThreadScope.newThread => EntryThreadScopeCopy.newThreadLabel,
  };

  String get helper => switch (this) {
    EntryThreadScope.noThread => EntryThreadScopeCopy.noThreadHelper,
    EntryThreadScope.existingThread =>
      EntryThreadScopeCopy.existingThreadHelper,
    EntryThreadScope.newThread => EntryThreadScopeCopy.newThreadHelper,
  };

  static EntryThreadScope? fromId(String? id) {
    if (id == null) return null;
    for (final scope in values) {
      if (scope.id == id) return scope;
    }
    return null;
  }
}

/// Session thread selection for the next save.
abstract class EntryThreadScopeSession {
  EntryThreadScopeSession._();

  static EntryThreadScope selectedScope = EntryThreadScope.noThread;
  static String? selectedThreadId;
  static String? pendingNewThreadName;
  static bool scopeExplicitlyChosen = false;

  static void selectScope(EntryThreadScope scope, {int? entryCount}) {
    if (EntryMemoryModeSession.selectedMode == EntryMemoryMode.keepSeparate) {
      return;
    }
    selectedScope = scope;
    scopeExplicitlyChosen = true;
    if (scope != EntryThreadScope.existingThread) {
      selectedThreadId = null;
    }
    if (scope != EntryThreadScope.newThread) {
      pendingNewThreadName = null;
    }
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryThreadScopeSelected,
      entryCount: entryCount,
      threadScope: scope.id,
      source: 'record',
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void selectExistingThread(String threadId, {int? entryCount}) {
    if (EntryMemoryModeSession.selectedMode == EntryMemoryMode.keepSeparate) {
      return;
    }
    selectedScope = EntryThreadScope.existingThread;
    selectedThreadId = threadId;
    scopeExplicitlyChosen = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryThreadScopeSelected,
      entryCount: entryCount,
      threadScope: EntryThreadScope.existingThread.id,
      source: 'record',
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void setPendingNewThreadName(String name) {
    pendingNewThreadName = name.trim();
    selectedScope = EntryThreadScope.newThread;
    scopeExplicitlyChosen = true;
  }

  /// Resolves the thread id to stamp on the entry at save time, or null.
  static String? resolveThreadIdForSave() {
    if (EntryMemoryModeSession.selectedMode == EntryMemoryMode.keepSeparate) {
      return null;
    }
    switch (selectedScope) {
      case EntryThreadScope.noThread:
        return null;
      case EntryThreadScope.existingThread:
        return selectedThreadId;
      case EntryThreadScope.newThread:
        return null; // created at save, id returned from store
    }
  }

  static void resetAfterSave() {
    selectedScope = EntryThreadScope.noThread;
    selectedThreadId = null;
    pendingNewThreadName = null;
    scopeExplicitlyChosen = false;
  }

  static void forceNoThread() {
    selectedScope = EntryThreadScope.noThread;
    selectedThreadId = null;
    pendingNewThreadName = null;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    selectedScope = EntryThreadScope.noThread;
    selectedThreadId = null;
    pendingNewThreadName = null;
    scopeExplicitlyChosen = false;
  }
}

abstract class EntryThreadScopeCopy {
  EntryThreadScopeCopy._();

  static const String sectionTitle = 'This belongs to';
  static const String noThreadLabel = 'No thread';
  static const String existingThreadLabel = 'Existing thread';
  static const String newThreadLabel = 'New thread';
  static const String noThreadHelper = 'Save without assigning a thread.';
  static const String existingThreadHelper =
      'Connect this to a thread you choose.';
  static const String newThreadHelper =
      'Start a new thread for related entries.';
  static const String emptyThreadsTitle = 'No threads yet';
  static const String emptyThreadsBody = 'Start a new thread instead.';

  static const List<String> all = [
    sectionTitle,
    noThreadLabel,
    existingThreadLabel,
    newThreadLabel,
    noThreadHelper,
    existingThreadHelper,
    newThreadHelper,
    emptyThreadsTitle,
    emptyThreadsBody,
  ];
}
