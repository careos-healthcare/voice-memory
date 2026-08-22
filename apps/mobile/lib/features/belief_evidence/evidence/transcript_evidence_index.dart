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
abstract final class TranscriptEvidenceIndex {
  TranscriptEvidenceIndex._();

  static final Map<String, _TranscriptSource> _sources = {};

  /// Registers text read from storage. Callers must never pass text produced
  /// by a summariser or any other generator.
  static void rememberStoredText({
    required String entryId,
    required String transcript,
    DateTime? recordedAt,
  }) {
    if (entryId.isEmpty || transcript.trim().isEmpty) return;
    _sources[entryId] = _TranscriptSource(
      transcript: transcript,
      recordedAt: recordedAt,
    );
  }

  static String? transcriptFor(String entryId) => _sources[entryId]?.transcript;

  static DateTime? recordedAtFor(String entryId) =>
      _sources[entryId]?.recordedAt;

  static bool hasSource(String entryId) => _sources.containsKey(entryId);

  static int get sourceCount => _sources.length;

  static void resetForTest() => _sources.clear();
}

class _TranscriptSource {
  const _TranscriptSource({required this.transcript, this.recordedAt});

  final String transcript;
  final DateTime? recordedAt;
}
