import 'package:archiveme_mobile/services/audio_structuring/audio_structuring.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_bootstrap.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';
import 'package:archiveme_mobile/services/local_llm/stub_local_llm_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioStructuringPrompt', () {
    test('buildChatMlPrompt wraps system and user roles', () {
      final prompt = AudioStructuringPrompt.buildChatMlPrompt(
        'um so like I went walking today uh yeah',
      );

      expect(prompt, contains('<|im_start|>system'));
      expect(prompt, contains('<|im_start|>user'));
      expect(prompt, contains('<|im_start|>assistant'));
      expect(prompt, contains(AudioStructuringPrompt.taskMarker));
      expect(prompt, contains('um so like I went walking today uh yeah'));
    });
  });

  group('AudioStructuringService', () {
    late AudioStructuringService service;

    setUp(() async {
      final llm = LocalLlmService(backend: StubLocalLlmBackend());
      await llm.loadModel(
        LocalLlmConfig.mobile(
          modelPath: '/tmp/stub-model-q4_k_m.gguf',
          requirePreferredQuantization: false,
          useChatMlFormat: false,
          maxTokens: AudioStructuringService.structuringMaxTokens,
        ),
      );
      service = AudioStructuringService(localLlm: llm);
    });

    test('structureTranscript returns cleaned journal entry offline', () async {
      final result = await service.structureTranscript(
        'um so I went walking today and uh it felt really calm',
      );

      expect(result.usedLocalLlm, isTrue);
      expect(result.rawTranscript, contains('walking today'));
      expect(result.structuredEntry.toLowerCase(), contains('walking today'));
      expect(result.structuredEntry.toLowerCase(), isNot(contains(' um ')));
    });

    test('structureTranscript rejects unusable transcripts', () async {
      expect(
        () => service.structureTranscript('...'),
        throwsA(isA<AudioStructuringException>()),
      );
    });

    test('createStub wires preformatted ChatML config', () async {
      final stubService = await AudioStructuringService.createStub();
      expect(stubService.isReady, isTrue);

      final result = await stubService.structureTranscript(
        'I keep saying yes even when I need rest and boundaries',
      );
      expect(result.structuredEntry, isNotEmpty);
    });

    test('tryCreate reuses injected LocalLlmService without reloading', () async {
      var loadCount = 0;
      final sharedLlm = LocalLlmService(
        backend: _CountingStubBackend(onLoad: () => loadCount++),
      );
      await sharedLlm.loadModel(
        LocalLlmBootstrap.productionConfig(
          modelPath: '/tmp/stub-model-q4_k_m.gguf',
          requirePreferredQuantization: false,
        ),
      );

      final service = await AudioStructuringService.tryCreate(
        localLlmOverride: sharedLlm,
      );

      expect(service, isNotNull);
      expect(loadCount, 1);
      expect(service!.isReady, isTrue);
    });
  });
}

final class _CountingStubBackend implements LocalLlmBackend {
  _CountingStubBackend({required this.onLoad});

  final void Function() onLoad;
  final StubLocalLlmBackend _delegate = StubLocalLlmBackend();

  @override
  bool get isLoaded => _delegate.isLoaded;

  @override
  Future<void> load(LocalLlmConfig config) async {
    onLoad();
    return _delegate.load(config);
  }

  @override
  Stream<LocalLlmTokenEvent> streamCompletion(
    LocalLlmCompletionRequest request,
  ) {
    return _delegate.streamCompletion(request);
  }

  @override
  Future<void> dispose() => _delegate.dispose();
}
