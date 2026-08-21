import 'package:archiveme_mobile/features/search/offline_reflection_search_guard.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:archiveme_mobile/services/audio_structuring/audio_structuring_prompt.dart';
import 'package:archiveme_mobile/services/audio_structuring/audio_structuring_result.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_bootstrap.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_model_contract.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_service.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';

/// Offline journal editor that structures raw STT transcripts via the local LLM isolate.
///
/// This service never performs network I/O — all inference runs on-device through
/// [LocalLlmService] and the llama.cpp worker isolate.
final class AudioStructuringService {
  AudioStructuringService({required LocalLlmService localLlm}) : _localLlm = localLlm;

  static const structuringMaxTokens = 384;

  final LocalLlmService _localLlm;

  bool get isReady => _localLlm.isLoaded;

  /// Creates a service when a sideloaded/bundled GGUF model is available.
  ///
  /// Pass [localLlmOverride] to reuse an already-loaded [LocalLlmService]
  /// (e.g. from [AppServices.resolveLocalLlm]) and avoid loading GGUF twice.
  static Future<AudioStructuringService?> tryCreate({
    String? documentsBasePath,
    String? libraryPath,
    LocalLlmService? localLlmOverride,
  }) async {
    final llm =
        localLlmOverride ??
        await LocalLlmBootstrap.tryCreate(
          documentsBasePath: documentsBasePath,
          libraryPath: libraryPath,
        );
    if (llm == null) return null;
    return AudioStructuringService(localLlm: llm);
  }

  /// Test/dev helper backed by [LocalLlmBootstrap.createStub].
  static Future<AudioStructuringService> createStub({
    LocalLlmService? localLlmOverride,
  }) async {
    final llm = localLlmOverride ?? await LocalLlmBootstrap.createStub();
    return AudioStructuringService(localLlm: llm);
  }

  /// Cleans, summarizes, and structures [rawTranscript] into a journal entry.
  Future<AudioStructuringResult> structureTranscript(String rawTranscript) {
    return _runOffline(() => _structureTranscript(rawTranscript));
  }

  Future<AudioStructuringResult> _structureTranscript(String rawTranscript) async {
    if (!_localLlm.isLoaded) {
      throw AudioStructuringException('Local LLM is not loaded.');
    }

    final verdict = TranscriptQuality.evaluate(rawTranscript);
    if (!verdict.isValid) {
      throw AudioStructuringException(
        'Transcript is not usable for structuring (${verdict.reason ?? 'invalid'}).',
      );
    }

    final chatMlPrompt = AudioStructuringPrompt.buildChatMlPrompt(verdict.normalized);
    final completion = await _localLlm.complete(
      LocalLlmCompletionRequest(
        prompt: chatMlPrompt,
        temperature: 0.15,
        maxTokens: structuringMaxTokens,
      ),
    );

    final structured = _sanitizeStructuredEntry(completion.text);
    if (structured.isEmpty) {
      throw AudioStructuringException('Local LLM returned an empty structured entry.');
    }

    return AudioStructuringResult(
      rawTranscript: verdict.normalized,
      structuredEntry: structured,
      usedLocalLlm: true,
    );
  }

  static String _sanitizeStructuredEntry(String rawCompletion) {
    var text = rawCompletion.trim();
    if (text.isEmpty) return '';

    text = text.replaceAll(RegExp(r'<\|im_start\|>[\s\S]*?(?:<\|im_end\|>|$)'), '');
    text = text.replaceAll(RegExp(r'<\|im_end\|>'), '');
    text = text.replaceAll(RegExp(r'^assistant\s*:', caseSensitive: false), '');
    text = _stripMarkdownFence(text);
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripMarkdownFence(String text) {
    final fenceMatch = RegExp(
      r'^```(?:[\w-]*\n)?([\s\S]*?)```$',
      multiLine: true,
    ).firstMatch(text.trim());
    if (fenceMatch != null) {
      return fenceMatch.group(1)?.trim() ?? text.trim();
    }
    return text.trim();
  }

  Future<T> _runOffline<T>(Future<T> Function() action) {
    return OfflineReflectionSearchGuard.runOffline(action);
  }
}
