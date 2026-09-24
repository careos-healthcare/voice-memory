/// Memory Scope — explicit, persistent control over when ArchiveMe uses
/// memory. Memory should be evidence, not gravity: the archive can connect
/// entries when there is enough evidence, and it can also leave entries
/// alone — permanently, if that is what the user chose.
library;

/// When ArchiveMe may use saved entries to suggest connections.
/// Stable ids only — safe for analytics and local storage.
enum MemoryScope {
  /// Connect entries when there is enough evidence (default).
  automatic,

  /// Ask before using a new entry to suggest a connection.
  ask,

  /// Compare entries only when an explicit shared thread/context marker
  /// already links them.
  threadOnly,

  /// Save entries without using them to suggest connections. Persistent;
  /// only the user can turn memory back on.
  off,
}

extension MemoryScopeId on MemoryScope {
  String get id => switch (this) {
    MemoryScope.automatic => 'automatic',
    MemoryScope.ask => 'ask',
    MemoryScope.threadOnly => 'thread_only',
    MemoryScope.off => 'off',
  };

  String get label => switch (this) {
    MemoryScope.automatic => MemoryScopeCopy.automaticLabel,
    MemoryScope.ask => MemoryScopeCopy.askLabel,
    MemoryScope.threadOnly => MemoryScopeCopy.threadOnlyLabel,
    MemoryScope.off => MemoryScopeCopy.offLabel,
  };

  String get helper => switch (this) {
    MemoryScope.automatic => MemoryScopeCopy.automaticHelper,
    MemoryScope.ask => MemoryScopeCopy.askHelper,
    MemoryScope.threadOnly => MemoryScopeCopy.threadOnlyHelper,
    MemoryScope.off => MemoryScopeCopy.offHelper,
  };

  static MemoryScope? fromId(String? id) => switch (id) {
    'automatic' => MemoryScope.automatic,
    'ask' => MemoryScope.ask,
    'thread_only' => MemoryScope.threadOnly,
    'off' => MemoryScope.off,
    _ => null,
  };
}

/// All consumer copy for memory scope — compile-time constants so tests
/// can sweep them and no private content can leak in. Calm, factual
/// wording only; no fear-based terms.
abstract class MemoryScopeCopy {
  MemoryScopeCopy._();

  // Mode labels + helpers.
  static const String automaticLabel = 'Automatic when useful';
  static const String automaticHelper =
      'ArchiveMe can connect entries when there is enough evidence.';
  static const String askLabel = 'Ask before connecting';
  static const String askHelper =
      'ArchiveMe will ask before using a new entry to suggest a connection.';
  static const String threadOnlyLabel = 'Only within chosen threads';
  static const String threadOnlyHelper =
      'ArchiveMe will not connect unrelated entries automatically.';
  static const String offLabel = 'Memory off';
  static const String offHelper =
      'ArchiveMe will save entries without using them to suggest '
      'connections.';

  // Settings section.
  static const String settingsTitle = 'Memory';
  static const String settingsBody = 'Choose when ArchiveMe connects entries.';

  // Recording-screen control.
  static const String entryControlTitle = 'Memory for this entry';
  static const String useCurrentSettingLabel = 'Use current setting';
  static const String offEntryTitle = 'Memory is off';
  static const String offEntryBody =
      'This entry will be saved without connection suggestions.';

  // Ask-mode connect prompt.
  static const String connectPromptTitle = 'Connect this to your archive?';
  static const String connectPromptBody =
      'This may relate to earlier evidence.';
  static const String connectLabel = 'Connect';
  static const String treatAsNewLabel = 'Treat as new';
  static const String connectConfirmed =
      'ArchiveMe can use this entry to suggest connections.';

  // Memory-off notice on insight surfaces.
  static const String offNoticeTitle = 'Memory is off.';
  static const String offNoticeBody =
      'Your entries are saved, but ArchiveMe is not connecting them '
      'right now.';
  static const String offNoticeCta = 'Change memory setting';
}
