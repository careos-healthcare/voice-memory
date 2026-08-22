import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/services/local_llm/local_llm_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';
import 'package:crypto/crypto.dart';

/// Deterministic local LLM backend for tests and offline development.
///
/// Streams pseudo-tokens derived from the prompt hash so callers can exercise
/// streaming + JSON extraction without a native llama.cpp library.
final class StubLocalLlmBackend implements LocalLlmBackend {
  StubLocalLlmBackend({this.chunkSize = 12});

  final int chunkSize;
  LocalLlmConfig? _config;

  @override
  bool get isLoaded => _config != null;

  @override
  Future<void> load(LocalLlmConfig config) async {
    _config = config;
  }

  @override
  Stream<LocalLlmTokenEvent> streamCompletion(
    LocalLlmCompletionRequest request,
  ) async* {
    _requireLoaded();
    final promptId = DateTime.now().microsecondsSinceEpoch.toString();
    final text = _syntheticCompletion(request.effectivePrompt);
    for (var offset = 0; offset < text.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, text.length);
      yield LocalLlmTokenEvent(
        token: text.substring(offset, end),
        promptId: promptId,
      );
      await Future<void>.delayed(Duration.zero);
    }
    yield LocalLlmTokenEvent(token: '', promptId: promptId, isFinal: true);
  }

  @override
  Future<void> dispose() async {
    _config = null;
  }

  void _requireLoaded() {
    if (_config == null) {
      throw StateError('StubLocalLlmBackend.load must be called first.');
    }
  }

  String _syntheticCompletion(String prompt) {
    if (prompt.contains('structure_journal_entry')) {
      final match = RegExp(
        r'Raw voice transcript:\s*"""([\s\S]*?)"""',
      ).firstMatch(prompt);
      final transcript = match?.group(1)?.trim() ?? '';
      if (transcript.isEmpty) {
        return 'Today I took time to reflect on what matters to me.';
      }
      final cleaned = transcript
          .replaceAll(RegExp(r'\b(um+|uh+|like|you know)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return cleaned.isEmpty
          ? 'Today I took time to reflect on what matters to me.'
          : cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    if (prompt.contains('knowledge_graph_update')) {
      return '''
{
  "entryId": "stub-entry",
  "tensionOrContradiction": "Wants to say no but keeps agreeing.",
  "nextSmallAction": "Pause before replying to the next request.",
  "recurringThemes": ["boundaries", "work"],
  "nodes": [
    {"id": "entry:stub-entry", "kind": "journal_entry", "label": "stub-entry"},
    {"id": "theme:boundaries:stub-entry", "kind": "theme", "label": "boundaries"}
  ],
  "edges": [
    {"from": "entry:stub-entry", "to": "theme:boundaries:stub-entry", "relation": "mentions_theme", "weight": 0.8}
  ]
}''';
    }

    final digest = sha256.convert(utf8.encode(prompt)).toString();
    return '[stub-llm:${digest.substring(0, 12)}] ${prompt.trim()}';
  }
}

/// Returns true when a native llama.cpp shared library is likely available.
bool localLlmNativeRuntimeSupported() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return false;
  }
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}
