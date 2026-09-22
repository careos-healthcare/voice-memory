/// On-device summary runner with a remote fallback.
///
/// The local engine is a thin binding over whatever runtime is on the phone:
/// a GGUF completion callback, an ONNX Runtime session, or a MediaPipe LLM
/// session. When those weights are not loaded, [ExtractiveInferenceEngine]
/// still writes a short summary from the entry and the retrieved passages.
/// If the network is up and a higher-precision model is allowed, the same
/// prompt is sent to [RemoteCompletionClient] instead.
library;

/// Which runtime produced a summary.
enum InferenceRoute { onDevice, remote }

/// Local weight format the completion callback is bound to.
enum LocalRuntime { gguf, onnx, mediaPipe, extractive }

/// A passage already retrieved by on-device vector search.
final class RetrievedPassage {
  const RetrievedPassage({
    required this.entryId,
    required this.text,
    required this.similarity,
  });

  final String entryId;
  final String text;
  final double similarity;
}

/// Entry text plus the passages a RAG search already ranked.
final class SummarySource {
  const SummarySource({required this.entryText, required this.passages});

  final String entryText;
  final List<RetrievedPassage> passages;
}

/// Completed summary, including which path produced it.
final class InferenceSummary {
  const InferenceSummary({
    required this.text,
    required this.route,
    required this.runtimeName,
    required this.elapsed,
    required this.passages,
  });

  final String text;
  final InferenceRoute route;
  final String runtimeName;
  final Duration elapsed;
  final List<RetrievedPassage> passages;
}

/// Loads nothing by itself. Callers bind GGUF, ONNX, or MediaPipe weights.
abstract interface class LocalInferenceEngine {
  String get runtimeName;

  Future<String> summarize(SummarySource source);
}

/// Remote completion used when the network and a larger model are available.
typedef RemoteCompletionClient = Future<String> Function(String prompt);

/// Looks up related passages before the summary is written.
typedef PassageRetriever =
    Future<List<RetrievedPassage>> Function(String query);

/// Binds a GGUF, ONNX Runtime, or MediaPipe session through one callback.
///
/// The app owns the native session. This wrapper only builds the summary
/// prompt and waits for the completion, so tests can substitute a fast
/// callback without shipping model weights.
final class BoundLocalEngine implements LocalInferenceEngine {
  BoundLocalEngine({required this.runtime, required this.complete})
    : assert(
        runtime != LocalRuntime.extractive,
        'Use ExtractiveInferenceEngine for the weight-free path',
      );

  final LocalRuntime runtime;
  final Future<String> Function(String prompt) complete;

  @override
  String get runtimeName => switch (runtime) {
    LocalRuntime.gguf => 'gguf',
    LocalRuntime.onnx => 'onnx',
    LocalRuntime.mediaPipe => 'mediapipe',
    LocalRuntime.extractive => 'extractive',
  };

  @override
  Future<String> summarize(SummarySource source) {
    return complete(summaryPrompt(source));
  }
}

/// Sentence extract used when no local weights are loaded.
///
/// It stays on the CPU for a few string copies, which is what keeps an
/// offline summary inside the mobile latency budget.
final class ExtractiveInferenceEngine implements LocalInferenceEngine {
  const ExtractiveInferenceEngine();

  @override
  String get runtimeName => 'extractive';

  @override
  Future<String> summarize(SummarySource source) async {
    return extractiveSummary(source);
  }
}

/// Prompt shared by GGUF, ONNX, and MediaPipe bindings.
String summaryPrompt(SummarySource source) {
  final buffer = StringBuffer('Summarize this journal entry in two sentences.\n')
    ..writeln(source.entryText.trim());
  if (source.passages.isNotEmpty) {
    buffer.writeln('Related moments:');
    for (final passage in source.passages.take(3)) {
      buffer.writeln('- ${passage.text.trim()}');
    }
  }
  return buffer.toString();
}

/// Two sentences from the entry, then one related moment when search hit.
String extractiveSummary(SummarySource source) {
  final sentences = _sentences(source.entryText);
  if (sentences.isEmpty && source.passages.isEmpty) {
    return 'Nothing to summarize yet.';
  }
  final buffer = StringBuffer();
  if (sentences.isEmpty) {
    buffer.write(source.passages.first.text.trim());
  } else {
    buffer.write(sentences.take(2).join(' '));
  }
  if (source.passages.isNotEmpty && sentences.isNotEmpty) {
    buffer
      ..write(' Related: ')
      ..write(source.passages.first.text.trim());
  }
  return buffer.toString();
}

/// Runs retrieval and a summary on-device, or defers to the remote model.
final class LocalInferenceService {
  LocalInferenceService({
    LocalInferenceEngine? onDevice,
    this.remote,
    this.retrieve,
  }) : onDevice = onDevice ?? const ExtractiveInferenceEngine();

  final LocalInferenceEngine onDevice;
  final RemoteCompletionClient? remote;
  final PassageRetriever? retrieve;

  /// Summarizes [entryText].
  ///
  /// When [query] and [retrieve] are set, related passages are collected
  /// first. The local engine writes the summary while offline. A remote
  /// client is used only when [networkAvailable] and
  /// [higherPrecisionAvailable] are both true.
  Future<InferenceSummary> summarize({
    required String entryText,
    String? query,
    bool networkAvailable = false,
    bool higherPrecisionAvailable = false,
  }) async {
    final watch = Stopwatch()..start();
    final passages = await _passagesFor(query);
    final source = SummarySource(entryText: entryText, passages: passages);
    final useRemote =
        networkAvailable && higherPrecisionAvailable && remote != null;
    if (useRemote) {
      final text = await remote!(summaryPrompt(source));
      return InferenceSummary(
        text: text,
        route: InferenceRoute.remote,
        runtimeName: 'remote',
        elapsed: watch.elapsed,
        passages: passages,
      );
    }
    final text = await onDevice.summarize(source);
    return InferenceSummary(
      text: text,
      route: InferenceRoute.onDevice,
      runtimeName: onDevice.runtimeName,
      elapsed: watch.elapsed,
      passages: passages,
    );
  }

  Future<List<RetrievedPassage>> _passagesFor(String? query) async {
    final trimmed = query?.trim();
    if (retrieve == null || trimmed == null || trimmed.isEmpty) {
      return const [];
    }
    return retrieve!(trimmed);
  }
}

List<String> _sentences(String text) {
  final sentences = <String>[];
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (char == '\n') {
      _flushSentence(sentences, buffer);
      continue;
    }
    buffer.write(char);
    if (char == '.' || char == '!' || char == '?') {
      _flushSentence(sentences, buffer);
    }
  }
  _flushSentence(sentences, buffer);
  return sentences;
}

void _flushSentence(List<String> sentences, StringBuffer buffer) {
  final sentence = buffer.toString().trim();
  buffer.clear();
  if (sentence.isNotEmpty) {
    sentences.add(sentence);
  }
}
