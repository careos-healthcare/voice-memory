/// Entry id → the stored transcript text a quote can be checked against.
///
/// Deliberately free of any model or storage import: the verifier and the
/// citation widgets depend on this, and they must stay cheap to construct and
/// to test. Journal entries are fed in by
/// `JournalTranscriptEvidenceIndexer`.
///
/// Only transcript text belongs here. Reflection fields
/// (`concreteObservation`, `exactLanguagePattern`, `tensionOrContradiction`)
/// are produced by analysis rather than spoken or typed by the user, so they
/// are not a source of truth for a verbatim quote even though the fact ledger
/// indexes them for contradiction matching.
///
/// That rule used to be a comment. It is now the shape of the API: the index
/// accepts [SpokenTranscript] and nothing else, so a caller cannot hand it a
/// bare `String` lifted off a reflection field.
abstract final class TranscriptEvidenceIndex {
  TranscriptEvidenceIndex._();

  static final Map<String, _TranscriptSource> _sources = {};

  /// Registers capture text read from storage.
  static void remember(SpokenTranscript spoken) {
    _sources[spoken.entryId] = _TranscriptSource(
      transcript: spoken.text,
      recordedAt: spoken.recordedAt,
    );
  }

  static String? transcriptFor(String entryId) => _sources[entryId]?.transcript;

  static DateTime? recordedAtFor(String entryId) =>
      _sources[entryId]?.recordedAt;

  static bool hasSource(String entryId) => _sources.containsKey(entryId);

  static int get sourceCount => _sources.length;

  static void resetForTest() => _sources.clear();
}

/// Text a user actually spoke or typed, carried as a distinct type so it
/// cannot be confused with generated text at a call site.
///
/// The constructor is private and the only mint point is
/// [SpokenTranscript.fromCaptureText], which takes the capture transcript of a
/// single entry. There is no factory that accepts a reflection, a summary, or
/// an insight, so analysis output has no route into the evidence index.
final class SpokenTranscript {
  const SpokenTranscript._({
    required this.entryId,
    required this.text,
    required this.recordedAt,
  });

  /// Wraps the stored capture transcript of an entry.
  ///
  /// Returns null when there is nothing quotable — an empty transcript, or a
  /// draft/system placeholder standing in for one. A failed transcription
  /// therefore contributes no evidence source at all, rather than contributing
  /// a placeholder that could later be presented as the user's words.
  static SpokenTranscript? fromCaptureText({
    required String entryId,
    required String? transcript,
    DateTime? recordedAt,
  }) {
    if (entryId.isEmpty) return null;
    final text = transcript?.trim() ?? '';
    if (text.isEmpty) return null;
    if (_isPlaceholder(text)) return null;
    return SpokenTranscript._(
      entryId: entryId,
      text: text,
      recordedAt: recordedAt,
    );
  }

  final String entryId;
  final String text;
  final DateTime? recordedAt;

  /// Mirrors `isDraftOrSystemTranscriptPlaceholder`, kept local so this file
  /// keeps its no-model-import guarantee.
  static bool _isPlaceholder(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('[draft]')) return true;
    if (lower == 'voice reflection') return true;
    const fragments = [
      'recording saved locally',
      'transcribe when connected',
      'saved privately on this device',
      'saved on this device. cloud processing pending.',
      'offline — saved as a draft',
      'you appear to be offline',
      'connection refused',
      'backend url not configured',
    ];
    for (final fragment in fragments) {
      if (lower.contains(fragment)) return true;
    }
    return false;
  }
}

class _TranscriptSource {
  const _TranscriptSource({required this.transcript, this.recordedAt});

  final String transcript;
  final DateTime? recordedAt;
}
