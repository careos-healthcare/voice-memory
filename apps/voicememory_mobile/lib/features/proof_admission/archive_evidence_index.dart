import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'proof_admission_models.dart';

/// Incremental, archive-scoped index of what the archive can currently
/// evidence.
///
/// The index exists to answer one question the admission pipeline cannot answer
/// on its own: *which earlier moments are related enough to be offered as
/// sources for a repeat or a change?* Without it every admission sees a single
/// entry, and a multi-source claim can never clear
/// `_claimAdmissionFailure`'s distinct-source minimum.
///
/// Two properties matter more than speed here:
///
/// * **No raw text is stored.** An entry contributes a set of salted term
///   digests. Relatedness is set overlap over those digests, so the index can
///   rank related moments without holding a second copy of the user's words.
///   The salt is per archive, so digests cannot be compared across archives
///   even if two files are placed side by side.
/// * **Staleness is detectable, not assumed.** Every record carries the
///   transcript revision it was built from. When an entry is edited the stored
///   revision no longer matches and the record is treated as invalid until
///   rebuilt, rather than silently answering from stale terms.
///
/// This is an implementation detail of admission and Changes. It is not a
/// surface, and nothing user-visible should render its counts directly.
class ArchiveEvidenceIndex {
  ArchiveEvidenceIndex({required this.archiveScope, required this.ownerScope});

  /// Bumped whenever the persisted shape changes. [fromJson] migrates forward
  /// and refuses to guess at anything newer than it understands.
  static const int schemaVersion = 1;

  /// Terms kept per entry. Caps the index's growth against a very long
  /// transcript while keeping enough signal to rank relatedness.
  static const int maxTermsPerEntry = 64;

  final String archiveScope;
  final String ownerScope;

  final Map<String, IndexedSource> _sources = {};
  final Map<String, FramingOccurrences> _framings = {};

  Iterable<IndexedSource> get sources => _sources.values;

  /// Adds or replaces the record for [entry].
  ///
  /// Entries belonging to another archive or owner are ignored rather than
  /// rejected loudly: the caller is usually iterating a mixed list, and a
  /// silently-scoped index is the behaviour that prevents cross-account leakage.
  void upsertEntry(ProofSourceEntry entry) {
    if (entry.archiveScope != archiveScope) return;
    if (entry.ownerScope != ownerScope) return;
    _sources[entry.entryId] = IndexedSource(
      entryId: entry.entryId,
      transcriptRevision: entry.transcriptRevision,
      createdAt: entry.createdAt,
      sourceType: entry.sourceType,
      deleted: entry.deleted,
      archived: entry.archived,
      terms: _terms(entry.transcript),
    );
  }

  void removeEntry(String entryId) {
    _sources.remove(entryId);
    for (final framing in _framings.values) {
      framing._forget(entryId);
    }
    _framings.removeWhere((_, framing) => framing.isEmpty);
  }

  /// Rebuilds from scratch. Used after a corrupt load, a schema migration, or
  /// any edit whose blast radius is unclear.
  void rebuild(Iterable<ProofSourceEntry> entries) {
    _sources.clear();
    _framings.clear();
    for (final entry in entries) {
      upsertEntry(entry);
    }
  }

  /// Entry IDs related to [entryId], most related first.
  ///
  /// Relatedness is Jaccard overlap of term digests. [minimumOverlap] is a
  /// floor rather than a tuned threshold: its job is to keep two moments that
  /// merely share filler out of each other's evidence, not to decide what
  /// counts as a pattern. That decision stays in the admission pipeline, which
  /// still has to verify exact quotes against whatever this returns.
  List<String> relatedSources(
    String entryId, {
    int limit = 8,
    double minimumOverlap = 0.12,
  }) {
    final subject = _sources[entryId];
    if (subject == null || !subject.usable) return const [];
    final scored = <_Scored>[];
    for (final candidate in _sources.values) {
      if (candidate.entryId == entryId || !candidate.usable) continue;
      final overlap = _overlap(subject.terms, candidate.terms);
      if (overlap < minimumOverlap) continue;
      scored.add(_Scored(candidate, overlap));
    }
    scored.sort((first, second) {
      final byOverlap = second.overlap.compareTo(first.overlap);
      if (byOverlap != 0) return byOverlap;
      // Older first on a tie: a repeat reads better anchored to the earliest
      // moment that supports it.
      final byDate = first.source.createdAt.compareTo(second.source.createdAt);
      if (byDate != 0) return byDate;
      return first.source.entryId.compareTo(second.source.entryId);
    });
    return List.unmodifiable(
      scored.take(limit).map((item) => item.source.entryId),
    );
  }

  /// Records that [framing] was evidenced by the given entries.
  void recordFraming({
    required String framing,
    required String claimKind,
    required Iterable<String> supportingEntryIds,
    Iterable<String> counterexampleEntryIds = const [],
    Iterable<String> contradictionEntryIds = const [],
  }) {
    final occurrences = _framings.putIfAbsent(
      framing,
      () => FramingOccurrences._(framing: framing, claimKind: claimKind),
    );
    for (final id in supportingEntryIds) {
      final source = _sources[id];
      if (source != null && source.usable) occurrences._support(source);
    }
    occurrences._counterexamples.addAll(counterexampleEntryIds);
    occurrences._contradictions.addAll(contradictionEntryIds);
  }

  FramingOccurrences? occurrences(String framing) => _framings[framing];

  /// Structural problems a caller should resolve by rebuilding.
  ///
  /// Returns human-readable reasons rather than a bool so a failure can be
  /// logged and acted on differently — a dangling reference is recoverable by
  /// pruning, a revision mismatch needs the entry re-read.
  List<String> integrityCheck() {
    final issues = <String>[];
    for (final framing in _framings.values) {
      for (final id in framing.supportingEntryIds) {
        if (!_sources.containsKey(id)) {
          issues.add('framing ${framing.framing} cites unknown source $id');
        }
      }
    }
    for (final source in _sources.values) {
      if (source.transcriptRevision.isEmpty) {
        issues.add('source ${source.entryId} has no transcript revision');
      }
    }
    return List.unmodifiable(issues);
  }

  /// True when [entry] has changed since it was indexed.
  bool isStale(ProofSourceEntry entry) {
    final indexed = _sources[entry.entryId];
    if (indexed == null) return true;
    return indexed.transcriptRevision != entry.transcriptRevision;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'archiveScope': archiveScope,
    'ownerScope': ownerScope,
    'sources': _sources.values.map((source) => source.toJson()).toList(),
    'framings': _framings.values.map((framing) => framing.toJson()).toList(),
  };

  /// Rebuilds an index from [json].
  ///
  /// Returns null when the payload is unusable — wrong archive, unknown future
  /// schema, or structurally corrupt. Callers treat null as "rebuild from the
  /// journal", which is always safe because the index derives entirely from
  /// entries it does not own.
  static ArchiveEvidenceIndex? fromJson(
    Map<String, dynamic> json, {
    required String archiveScope,
    required String ownerScope,
  }) {
    final version = json['schemaVersion'];
    if (version is! int || version > schemaVersion) return null;
    if (json['archiveScope'] != archiveScope) return null;
    if (json['ownerScope'] != ownerScope) return null;
    final index = ArchiveEvidenceIndex(
      archiveScope: archiveScope,
      ownerScope: ownerScope,
    );
    try {
      for (final raw in (json['sources'] as List? ?? const [])) {
        final source = IndexedSource.fromJson(raw as Map<String, dynamic>);
        index._sources[source.entryId] = source;
      }
      for (final raw in (json['framings'] as List? ?? const [])) {
        final framing = FramingOccurrences.fromJson(
          raw as Map<String, dynamic>,
        );
        index._framings[framing.framing] = framing;
      }
    } catch (_) {
      // A partially-read index is worse than none: it would answer relatedness
      // from half an archive and quietly starve real repeats of their sources.
      return null;
    }
    return index;
  }

  Set<String> _terms(String transcript) {
    final counts = <String, int>{};
    for (final word
        in transcript
            .toLowerCase()
            .replaceAll(RegExp(r"[^\p{L}\p{N}\s']", unicode: true), ' ')
            .split(RegExp(r'\s+'))) {
      if (word.length < 3 || _stopWords.contains(word)) continue;
      counts[_stem(word)] = (counts[_stem(word)] ?? 0) + 1;
    }
    final ordered = counts.keys.toList()
      ..sort((first, second) {
        final byCount = counts[second]!.compareTo(counts[first]!);
        return byCount != 0 ? byCount : first.compareTo(second);
      });
    return ordered.take(maxTermsPerEntry).map(_digest).toSet();
  }

  /// Salted with the archive scope so the same word yields different digests in
  /// different archives.
  String _digest(String term) => sha256
      .convert(utf8.encode('archive_term_v1|$archiveScope|$term'))
      .toString()
      .substring(0, 16);

  static String _stem(String word) {
    for (final suffix in const ['ing', 'ed', 'es', 's']) {
      if (word.length > suffix.length + 2 && word.endsWith(suffix)) {
        return word.substring(0, word.length - suffix.length);
      }
    }
    return word;
  }

  static double _overlap(Set<String> first, Set<String> second) {
    if (first.isEmpty || second.isEmpty) return 0;
    final shared = first.intersection(second).length;
    if (shared == 0) return 0;
    return shared / first.union(second).length;
  }

  static const Set<String> _stopWords = {
    'about',
    'after',
    'again',
    'and',
    'because',
    'been',
    'before',
    'being',
    'but',
    'could',
    'did',
    'does',
    'doing',
    'for',
    'from',
    'had',
    'has',
    'have',
    'having',
    'her',
    'his',
    'into',
    'its',
    'just',
    'like',
    'more',
    'much',
    'not',
    'now',
    'off',
    'only',
    'other',
    'our',
    'out',
    'over',
    'own',
    'really',
    'same',
    'she',
    'should',
    'some',
    'still',
    'such',
    'than',
    'that',
    'the',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'too',
    'under',
    'very',
    'was',
    'were',
    'what',
    'when',
    'where',
    'which',
    'while',
    'who',
    'why',
    'will',
    'with',
    'would',
    'you',
    'your',
  };
}

/// One entry as the index sees it: when it happened, what revision it was read
/// at, and a digest of what it was about.
class IndexedSource {
  const IndexedSource({
    required this.entryId,
    required this.transcriptRevision,
    required this.createdAt,
    required this.sourceType,
    required this.deleted,
    required this.archived,
    required this.terms,
  });

  final String entryId;
  final String transcriptRevision;
  final DateTime createdAt;
  final ProofSourceType sourceType;
  final bool deleted;
  final bool archived;
  final Set<String> terms;

  /// Deleted and archived entries stay indexed so existing proofs can still
  /// explain which moment they came from, but they never seed new evidence.
  bool get usable => !deleted && !archived && terms.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'transcriptRevision': transcriptRevision,
    'createdAt': createdAt.toIso8601String(),
    'sourceType': sourceType.name,
    'deleted': deleted,
    'archived': archived,
    'terms': terms.toList(),
  };

  static IndexedSource fromJson(Map<String, dynamic> json) => IndexedSource(
    entryId: json['entryId'] as String,
    transcriptRevision: json['transcriptRevision'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    sourceType: ProofSourceType.values.firstWhere(
      (value) => value.name == json['sourceType'],
      orElse: () => ProofSourceType.userTyped,
    ),
    deleted: json['deleted'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    terms: ((json['terms'] as List? ?? const []).cast<String>()).toSet(),
  );
}

/// How often one framing has actually been evidenced, and when.
class FramingOccurrences {
  FramingOccurrences._({required this.framing, required this.claimKind});

  final String framing;
  final String claimKind;
  final Map<String, DateTime> _supporting = {};
  final Set<String> _counterexamples = {};
  final Set<String> _contradictions = {};

  void _support(IndexedSource source) {
    _supporting[source.entryId] = source.createdAt;
  }

  void _forget(String entryId) {
    _supporting.remove(entryId);
    _counterexamples.remove(entryId);
    _contradictions.remove(entryId);
  }

  bool get isEmpty =>
      _supporting.isEmpty &&
      _counterexamples.isEmpty &&
      _contradictions.isEmpty;

  Iterable<String> get supportingEntryIds => _supporting.keys;

  Set<String> get counterexampleEntryIds => Set.unmodifiable(_counterexamples);

  Set<String> get contradictionEntryIds => Set.unmodifiable(_contradictions);

  /// Distinct moments supporting this framing. This is the number a repeat
  /// claim is allowed to lean on — never a count of citations, which could be
  /// several quotes from a single entry.
  int get occurrenceCount => _supporting.length;

  DateTime? get firstOccurrence => _extreme(earliest: true);

  DateTime? get latestOccurrence => _extreme(earliest: false);

  /// Supporting moments within [window] of [now]. Counts only what is logged;
  /// nothing is extrapolated across a gap.
  int countWithin(Duration window, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(window);
    return _supporting.values.where((date) => date.isAfter(cutoff)).length;
  }

  DateTime? _extreme({required bool earliest}) {
    if (_supporting.isEmpty) return null;
    return _supporting.values.reduce(
      (a, b) => (earliest ? a.isBefore(b) : a.isAfter(b)) ? a : b,
    );
  }

  Map<String, dynamic> toJson() => {
    'framing': framing,
    'claimKind': claimKind,
    'supporting': _supporting.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    'counterexamples': _counterexamples.toList(),
    'contradictions': _contradictions.toList(),
  };

  static FramingOccurrences fromJson(Map<String, dynamic> json) {
    final occurrences = FramingOccurrences._(
      framing: json['framing'] as String,
      claimKind: json['claimKind'] as String? ?? '',
    );
    final supporting = json['supporting'] as Map<String, dynamic>? ?? const {};
    supporting.forEach((key, value) {
      occurrences._supporting[key] = DateTime.parse(value as String);
    });
    occurrences._counterexamples.addAll(
      (json['counterexamples'] as List? ?? const []).cast<String>(),
    );
    occurrences._contradictions.addAll(
      (json['contradictions'] as List? ?? const []).cast<String>(),
    );
    return occurrences;
  }
}

class _Scored {
  const _Scored(this.source, this.overlap);

  final IndexedSource source;
  final double overlap;
}
