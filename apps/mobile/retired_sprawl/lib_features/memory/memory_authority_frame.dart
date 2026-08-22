import 'package:archiveme_mobile/features/memory/memory_influence_level.dart';

/// What the archive evidence behind a memory card currently is — its
/// authority, not just its existence. Retrieval finds evidence; the
/// authority state says how that evidence may speak about the present.
enum MemoryAuthorityState {
  /// Recent supported evidence with nothing newer contradicting it.
  current,

  /// The same signal appeared in several separate recent entries.
  repeated,

  /// The user explicitly confirmed/approved the connection.
  confirmed,

  /// Older evidence that was not reinforced recently.
  stale,

  /// The archive moved on after this evidence — it is not current.
  superseded,

  /// The evidence points in more than one direction.
  conflicting,

  /// Near-identical entries grouped so repetition is not inflated.
  duplicate,

  /// The entry is being kept separate — no connection authority at all.
  fresh,
}

extension MemoryAuthorityStateId on MemoryAuthorityState {
  /// Stable analytics id — never user text.
  String get id => switch (this) {
    MemoryAuthorityState.current => 'current',
    MemoryAuthorityState.repeated => 'repeated',
    MemoryAuthorityState.confirmed => 'confirmed',
    MemoryAuthorityState.stale => 'stale',
    MemoryAuthorityState.superseded => 'superseded',
    MemoryAuthorityState.conflicting => 'conflicting',
    MemoryAuthorityState.duplicate => 'duplicate',
    MemoryAuthorityState.fresh => 'fresh',
  };

  /// Consumer-facing authority label.
  String get label => switch (this) {
    MemoryAuthorityState.current => 'Still current',
    MemoryAuthorityState.repeated => 'Repeated evidence',
    MemoryAuthorityState.confirmed => 'User confirmed',
    MemoryAuthorityState.stale => 'May be stale',
    MemoryAuthorityState.superseded => 'Changed later',
    MemoryAuthorityState.conflicting => 'Mixed evidence',
    MemoryAuthorityState.duplicate => 'Grouped duplicates',
    MemoryAuthorityState.fresh => 'Fresh entry',
  };
}

/// Stable reason ids a frame can carry — whitelisted for analytics.
abstract class MemoryAuthorityReason {
  MemoryAuthorityReason._();

  static const String recentSupported = 'recent_supported';
  static const String repeatedSupported = 'repeated_supported';
  static const String userConfirmed = 'user_confirmed';
  static const String olderUnreinforced = 'older_unreinforced';
  static const String changedLater = 'changed_later';
  static const String mixedEvidence = 'mixed_evidence';
  static const String groupedDuplicate = 'grouped_duplicate';
  static const String freshEntry = 'fresh_entry';
  static const String memoryOff = 'memory_off';
  static const String unapproved = 'unapproved';
}

/// The structured frame that travels with archive evidence into a memory
/// card: explicit authority and influence instead of vague context. No
/// memory evidence enters a card without one of these, and the frame
/// carries stable ids only — never notes, snippets, dates, or entry ids.
class MemoryAuthorityFrame {
  const MemoryAuthorityFrame({
    required this.authorityState,
    required this.influenceLevel,
    required this.reasonId,
    required this.cardType,
  });

  final MemoryAuthorityState authorityState;
  final MemoryInfluenceLevel influenceLevel;

  /// One of the [MemoryAuthorityReason] stable ids.
  final String reasonId;

  /// Stable card id (e.g. `thread_return`) — never dynamic text.
  final String cardType;

  /// Whether memory engines may build connection claims from evidence
  /// framed this way.
  bool get allowsConnectionClaims => influenceLevel.allowsConnectionClaims;

  /// Cautious-copy signal: the evidence may render, but confident
  /// wording is not supported.
  bool get requiresCautiousCopy =>
      authorityState == MemoryAuthorityState.conflicting ||
      authorityState == MemoryAuthorityState.stale ||
      authorityState == MemoryAuthorityState.superseded;
}

/// All consumer copy for authority framing — compile-time constants so
/// tests can sweep them and no private content can leak in.
abstract class MemoryAuthorityCopy {
  MemoryAuthorityCopy._();

  /// Explanation action + sheet title.
  static const String actionLabel = 'How this memory was used';
  static const String sheetTitle = 'How this memory was used';

  /// Sheet body by influence level.
  static const String blockedBody =
      'Memory is off, so ArchiveMe is not using previous entries here.';
  static const String suppressBody =
      'This entry is being kept separate from connection suggestions.';
  static const String backgroundBody =
      'ArchiveMe found related evidence, but it is being treated '
      'cautiously.';
  static const String compareBody =
      'ArchiveMe found enough eligible evidence to compare this with '
      'your archive.';
  static const String highAuthorityBody =
      'You previously confirmed this connection, so ArchiveMe gives it '
      'more weight.';

  static const String sheetFooter =
      'You can mark a connection as not related if it does not fit.';

  static String bodyFor(MemoryInfluenceLevel level) => switch (level) {
    MemoryInfluenceLevel.blocked => blockedBody,
    MemoryInfluenceLevel.suppress => suppressBody,
    MemoryInfluenceLevel.background => backgroundBody,
    MemoryInfluenceLevel.compare => compareBody,
    MemoryInfluenceLevel.highAuthority => highAuthorityBody,
  };
}