import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/llm/native/llama_inference_session.dart';
import 'package:voicememory_mobile/core/llm/native/llama_native_backend.dart';

void main() {
  group('LlamaInferenceSession', () {
    test('warms, infers, and disposes through a worker isolate', () async {
      final session = LlamaInferenceSession(backendFactory: _fakeFactory);

      expect(session.state, LlamaInferenceSessionState.idle);
      await session.warmUp(modelPath: '/tmp/fake.gguf');
      expect(session.isReady, isTrue);
      expect(session.status, LlamaInferenceSessionState.ready);

      final response = await session.inferDetailed('hello');
      expect(response.requestId, 2);
      expect(response.result.inferenceDriver, 'llama.cpp');
      expect(response.result.entities.single.label, 'hello');
      expect(response.rawGeneratedJson, contains('"entities"'));
      final result = await session.infer('hello');
      expect(result.entities.single.label, 'hello');
      expect(await session.inferRaw('raw-text'), 'Private local summary.');
      await session.loadAdapter('/tmp/personal.gguf', scale: .75);
      await session.unloadAdapter();

      await session.dispose();
      expect(session.state, LlamaInferenceSessionState.disposed);
      expect(() => session.infer('later'), throwsStateError);
    });

    test('serializes concurrent requests in request-id order', () async {
      final session = LlamaInferenceSession(backendFactory: _fakeFactory);
      await session.warmUp(modelPath: '/tmp/fake.gguf');
      final completed = <int>[];

      final first = session
          .inferDetailed('slow:first')
          .then((response) => completed.add(response.requestId));
      final second = session
          .inferDetailed('fast:second')
          .then((response) => completed.add(response.requestId));

      await Future.wait([first, second]);
      expect(completed, [2, 3]);
      await session.dispose();
    });

    test('times out without making the session ready state unsafe', () async {
      final session = LlamaInferenceSession(backendFactory: _fakeFactory);
      await session.warmUp(modelPath: '/tmp/fake.gguf');

      await expectLater(
        session.infer(
          'slow:timeout',
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(session.isReady, isTrue);

      await session.dispose();
    });

    test('surfaces worker failure and remains usable', () async {
      final session = LlamaInferenceSession(backendFactory: _fakeFactory);
      await session.warmUp(modelPath: '/tmp/fake.gguf');

      await expectLater(
        session.infer('fail'),
        throwsA(isA<LlamaWorkerException>()),
      );
      final recovered = await session.infer('recovered');
      expect(recovered.isValid, isTrue);

      await session.dispose();
    });

    test('rejects malformed or semantically invalid model output', () async {
      final session = LlamaInferenceSession(backendFactory: _fakeFactory);
      await session.warmUp(modelPath: '/tmp/fake.gguf');

      await expectLater(
        session.infer('malformed'),
        throwsA(isA<LlamaInvalidOutputException>()),
      );
      await expectLater(
        session.infer('invalid-schema'),
        throwsA(isA<LlamaInvalidOutputException>()),
      );

      await session.dispose();
    });

    test('fails closed when warm-up backend is unavailable', () async {
      final session = LlamaInferenceSession(
        backendFactory: _unavailableFactory,
      );

      await expectLater(
        session.warmUp(modelPath: '/tmp/missing.gguf'),
        throwsA(isA<LlamaRuntimeUnavailableException>()),
      );
      expect(session.state, LlamaInferenceSessionState.failed);
      expect(() => session.infer('no native runtime'), throwsStateError);

      await session.dispose();
    });

    test('validates context, token, and timeout bounds', () async {
      final session = LlamaInferenceSession(backendFactory: _fakeFactory);

      expect(
        () => session.warmUp(modelPath: '/tmp/fake.gguf', contextSize: 128),
        throwsRangeError,
      );
      await session.warmUp(modelPath: '/tmp/fake.gguf');
      expect(() => session.infer('x', maxTokens: 2048), throwsRangeError);
      expect(
        () => session.infer('x', timeout: Duration.zero),
        throwsRangeError,
      );

      await session.dispose();
    });
  });
}

LlamaInferenceBackend _fakeFactory() => _FakeBackend();

LlamaInferenceBackend _unavailableFactory() => _UnavailableBackend();

final class _FakeBackend implements LlamaInferenceBackend {
  bool _ready = false;
  bool _disposed = false;

  @override
  bool get isReady => _ready && !_disposed;

  @override
  void warmUp({
    required String modelPath,
    required int contextSize,
    required int threads,
    required int gpuLayers,
  }) {
    _ready = true;
  }

  @override
  String infer({
    required String prompt,
    required int maxTokens,
    required Duration timeout,
  }) {
    if (!isReady) throw StateError('not ready');
    if (prompt == 'raw-text') return 'Private local summary.';
    if (!prompt.contains('Return exactly one JSON object') ||
        !prompt.contains('Never invent evidence')) {
      throw StateError('strict JSON extraction prompt was not applied');
    }
    if (prompt.contains('slow:')) {
      sleep(const Duration(milliseconds: 60));
    }
    if (prompt.contains('"fail"')) throw StateError('fixture failure');
    if (prompt.contains('"malformed"')) return 'not json';
    if (prompt.contains('"invalid-schema"')) {
      return '{"entities":[],"relations":[],"sentiment":0,"confidence":0}';
    }
    final inputMatch = RegExp(
      r'INPUT:\s*("(?:[^"\\]|\\.)*")',
    ).firstMatch(prompt);
    final label = jsonDecode(inputMatch!.group(1)!) as String;
    return '''
{"entities":[{"type":"event","label":${jsonEncode(label)},"confidence":0.9,"sentiment":0.1,"excerpt":${jsonEncode(label)},"startUtf16":0,"endUtf16":${label.length}}],"relations":[],"sentiment":0.1,"confidence":0.9}
''';
  }

  @override
  void cancel() {}

  @override
  void loadAdapter({required String adapterPath, required double scale}) {}

  @override
  void unloadAdapter() {}

  @override
  void dispose() {
    _disposed = true;
    _ready = false;
  }
}

final class _UnavailableBackend implements LlamaInferenceBackend {
  @override
  bool get isReady => false;

  @override
  void warmUp({
    required String modelPath,
    required int contextSize,
    required int threads,
    required int gpuLayers,
  }) {
    throw const LlamaRuntimeUnavailableException('fixture unavailable');
  }

  @override
  String infer({
    required String prompt,
    required int maxTokens,
    required Duration timeout,
  }) => throw StateError('unavailable');

  @override
  void cancel() {}

  @override
  void loadAdapter({required String adapterPath, required double scale}) {}

  @override
  void unloadAdapter() {}

  @override
  void dispose() {}
}
