enum LlamaModelCatalogState { configured, notConfigured }

final class LlamaModelDescriptor {
  const LlamaModelDescriptor({
    required this.id,
    required this.revision,
    required this.url,
    required this.sha256,
    required this.expectedBytes,
    required this.estimatedDisplaySize,
    required this.license,
    required this.attribution,
  });

  final String id;
  final String revision;
  final Uri url;
  final String sha256;
  final int expectedBytes;
  final String estimatedDisplaySize;
  final String license;
  final String attribution;
}

final class LlamaModelCatalog {
  const LlamaModelCatalog._({required this.state, this.model});

  static const modelId = 'qwen2.5-1.5b-instruct-q4-k-m';
  static const revision = 'qwen2.5-1.5b-instruct-q4_k_m';
  static const minimumExpectedBytes = 512 * 1024 * 1024;
  static const maximumExpectedBytes = 4 * 1024 * 1024 * 1024;

  final LlamaModelCatalogState state;
  final LlamaModelDescriptor? model;

  static LlamaModelCatalog configured(LlamaModelDescriptor model) =>
      LlamaModelCatalog._(
        state: LlamaModelCatalogState.configured,
        model: model,
      );

  static LlamaModelCatalog fromBuildEnvironment({
    String url = const String.fromEnvironment('LLAMA_MODEL_URL'),
    String sha256 = const String.fromEnvironment('LLAMA_MODEL_SHA256'),
    String expectedBytes = const String.fromEnvironment('LLAMA_MODEL_BYTES'),
  }) {
    final uri = Uri.tryParse(url.trim());
    final hash = sha256.trim().toLowerCase();
    final bytes = int.tryParse(expectedBytes.trim());
    final valid =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        hash.length == 64 &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) &&
        bytes != null &&
        bytes >= minimumExpectedBytes &&
        bytes <= maximumExpectedBytes;
    if (!valid) {
      return const LlamaModelCatalog._(
        state: LlamaModelCatalogState.notConfigured,
      );
    }
    return LlamaModelCatalog._(
      state: LlamaModelCatalogState.configured,
      model: LlamaModelDescriptor(
        id: modelId,
        revision: revision,
        url: uri,
        sha256: hash,
        expectedBytes: bytes,
        estimatedDisplaySize: _displaySize(bytes),
        license: 'Apache-2.0',
        attribution:
            'Qwen2.5 1.5B Instruct Q4_K_M by Alibaba Cloud (Qwen Team)',
      ),
    );
  }

  static String _displaySize(int bytes) {
    final gib = bytes / (1024 * 1024 * 1024);
    return '${gib.toStringAsFixed(gib >= 10 ? 0 : 1)} GiB';
  }
}
