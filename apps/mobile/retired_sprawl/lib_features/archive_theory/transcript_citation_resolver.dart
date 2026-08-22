import 'package:archiveme_mobile/models/journal_entry.dart';

/// Resolved audio/transcript anchor for a cited quote.
class TranscriptCitationReference {
  const TranscriptCitationReference({
    required this.audioId,
    required this.startTimestampMs,
    required this.endTimestampMs,
    required this.chunkId,
    required this.entryId,
    required this.quote,
    required this.startUtf16,
    required this.endUtf16,
  });

  final String audioId;
  final int startTimestampMs;
  final int endTimestampMs;
  final String chunkId;
  final String entryId;
  final String quote;
  final int startUtf16;
  final int endUtf16;

  bool get hasPlayback =>
      audioId.isNotEmpty && startTimestampMs >= 0 && endTimestampMs > startTimestampMs;
}

/// Maps journal transcripts to playback-ready citation metadata.
class TranscriptCitationResolver {
  const TranscriptCitationResolver();

  TranscriptCitationReference resolve({
    required JournalEntry entry,
    required String quote,
  }) {
    final transcript = entry.transcript;
    final trimmedQuote = quote.trim();
    final span = _resolveSpan(transcript, trimmedQuote);

    final durationMs = (entry.durationSeconds * 1000).clamp(0, 86400000);
    final startTimestampMs = durationMs == 0 || transcript.isEmpty
        ? 0
        : ((span.$1 / transcript.length) * durationMs).round().clamp(0, durationMs);
    final endTimestampMs = durationMs == 0 || transcript.isEmpty
        ? 0
        : ((span.$2 / transcript.length) * durationMs)
            .round()
            .clamp(startTimestampMs, durationMs);

    final audioId = entry.id;
    final chunkId = '$audioId:$startTimestampMs';

    return TranscriptCitationReference(
      audioId: audioId,
      startTimestampMs: startTimestampMs,
      endTimestampMs: endTimestampMs,
      chunkId: chunkId,
      entryId: entry.id,
      quote: trimmedQuote,
      startUtf16: span.$1,
      endUtf16: span.$2,
    );
  }

  /// Builds a trimmed quote around belief keywords for citation display.
  String quoteForBelief(JournalEntry entry, String beliefText) {
    final transcript = entry.transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (transcript.isEmpty) return '';

    final keywords = _keywordsFrom(beliefText);
    if (keywords.isEmpty) return _trimQuote(transcript);

    final lower = transcript.toLowerCase();
    var firstIndex = -1;
    for (final keyword in keywords) {
      final index = lower.indexOf(keyword);
      if (index >= 0 && (firstIndex < 0 || index < firstIndex)) {
        firstIndex = index;
      }
    }
    if (firstIndex < 0) return _trimQuote(transcript);

    const window = 120;
    final start = (firstIndex - 40).clamp(0, transcript.length);
    final end = (firstIndex + window).clamp(0, transcript.length);
    var excerpt = transcript.substring(start, end).trim();
    if (start > 0) excerpt = '…$excerpt';
    if (end < transcript.length) excerpt = '$excerpt…';
    return _trimQuote(excerpt);
  }

  (int, int) _resolveSpan(String transcript, String quote) {
    if (transcript.isEmpty) return (0, 0);
    if (quote.isEmpty) return (0, transcript.length.clamp(0, transcript.length));

    final direct = transcript.indexOf(quote);
    if (direct >= 0) return (direct, direct + quote.length);

    final normalizedTranscript = transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedQuote = quote.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedIndex = normalizedTranscript.indexOf(normalizedQuote);
    if (normalizedIndex >= 0) {
      final mapped = _mapNormalizedSpan(
        transcript,
        normalizedTranscript,
        normalizedIndex,
        normalizedQuote.length,
      );
      if (mapped != null) return mapped;
    }

    final probe = normalizedQuote.length > 24
        ? normalizedQuote.substring(0, 24)
        : normalizedQuote;
    final probeIndex = normalizedTranscript.toLowerCase().indexOf(probe.toLowerCase());
    if (probeIndex >= 0) {
      final mapped = _mapNormalizedSpan(
        transcript,
        normalizedTranscript,
        probeIndex,
        probe.length,
      );
      if (mapped != null) return mapped;
    }

    return (0, transcript.length);
  }

  (int, int)? _mapNormalizedSpan(
    String original,
    String normalized,
    int normalizedStart,
    int normalizedLength,
  ) {
    if (normalized.isEmpty || original.isEmpty) return null;
    final ratio = original.length / normalized.length;
    final start = (normalizedStart * ratio).round().clamp(0, original.length);
    final end = ((normalizedStart + normalizedLength) * ratio)
        .round()
        .clamp(start, original.length);
    return (start, end);
  }

  Set<String> _keywordsFrom(String belief) {
    return belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
  }

  String _trimQuote(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 200) return normalized;
    return '${normalized.substring(0, 197)}…';
  }
}
