import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/llm/llama_model_catalog.dart';

void main() {
  test(
    'build configuration is strict and absent values are not configured',
    () {
      expect(
        LlamaModelCatalog.fromBuildEnvironment().state,
        LlamaModelCatalogState.notConfigured,
      );
      expect(
        LlamaModelCatalog.fromBuildEnvironment(
          url: 'http://example.com/model.gguf',
          sha256: 'a' * 64,
          expectedBytes: '1',
        ).state,
        LlamaModelCatalogState.notConfigured,
      );
      expect(
        LlamaModelCatalog.fromBuildEnvironment(
          url: 'https://example.com/model.gguf',
          sha256: 'not-a-hash',
          expectedBytes: '1',
        ).state,
        LlamaModelCatalogState.notConfigured,
      );
      expect(
        LlamaModelCatalog.fromBuildEnvironment(
          url: 'https://example.com/model.gguf',
          sha256: 'a' * 64,
          expectedBytes: '0',
        ).state,
        LlamaModelCatalogState.notConfigured,
      );
    },
  );

  test('configured catalog includes pinned model disclosures', () {
    final catalog = LlamaModelCatalog.fromBuildEnvironment(
      url: 'https://models.example/qwen.gguf',
      sha256: 'a' * 64,
      expectedBytes: '${1536 * 1024 * 1024}',
    );

    expect(catalog.state, LlamaModelCatalogState.configured);
    expect(catalog.model!.id, contains('qwen2.5-1.5b'));
    expect(catalog.model!.revision, isNotEmpty);
    expect(catalog.model!.license, 'Apache-2.0');
    expect(catalog.model!.attribution, contains('Qwen'));
    expect(catalog.model!.estimatedDisplaySize, '1.5 GiB');
  });
}
