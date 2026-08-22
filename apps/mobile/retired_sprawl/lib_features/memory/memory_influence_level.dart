/// How much influence one piece of archive evidence is allowed to have
/// on the present entry. Memory should be evidence, not gravity: finding
/// a memory and letting it speak are separate decisions, and this level
/// is the explicit second decision.
enum MemoryInfluenceLevel {
  /// Memory scope is off — no archive evidence is used at all.
  blocked,

  /// The evidence exists but is kept out of connection suggestions
  /// (fresh entries, unapproved ask-mode entries).
  suppress,

  /// Related evidence is acknowledged but treated cautiously — it can
  /// not back a major memory claim on its own.
  background,

  /// Enough eligible evidence to compare the present with the archive.
  compare,

  /// The user confirmed this connection, so it carries more weight.
  /// Retrieval relevance alone can not reach this level.
  highAuthority,
}

extension MemoryInfluenceLevelId on MemoryInfluenceLevel {
  /// Stable analytics id — never user text.
  String get id => switch (this) {
    MemoryInfluenceLevel.blocked => 'blocked',
    MemoryInfluenceLevel.suppress => 'suppress',
    MemoryInfluenceLevel.background => 'background',
    MemoryInfluenceLevel.compare => 'compare',
    MemoryInfluenceLevel.highAuthority => 'high_authority',
  };

  /// Consumer-facing influence label.
  String get label => switch (this) {
    MemoryInfluenceLevel.blocked => 'Memory blocked',
    MemoryInfluenceLevel.suppress => 'Not used for connection',
    MemoryInfluenceLevel.background => 'Background evidence',
    MemoryInfluenceLevel.compare => 'Compared with archive',
    MemoryInfluenceLevel.highAuthority => 'User confirmed',
  };

  /// Whether memory engines may build connection claims at this level.
  bool get allowsConnectionClaims =>
      this == MemoryInfluenceLevel.compare ||
      this == MemoryInfluenceLevel.highAuthority;
}