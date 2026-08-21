import 'package:archiveme_mobile/services/local_llm/model_download_progress.dart';

/// Remote GGUF download, on-disk placement, and first-launch provisioning.
abstract final class ModelDownloadContract {
  ModelDownloadContract._();

  /// Default TinyLlama Q4_K_M instruct weights for on-device structuring.
  static const defaultRemoteModelUrl =
      'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';

  /// Override at build time:
  /// `--dart-define=LOCAL_LLM_MODEL_URL=https://.../model.Q4_K_M.gguf`
  static const remoteModelUrlDefineKey = 'LOCAL_LLM_MODEL_URL';

  static String remoteModelUrl({String? override}) {
    if (override != null && override.isNotEmpty) {
      return override;
    }
    const fromDefine = String.fromEnvironment(
      remoteModelUrlDefineKey,
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    return defaultRemoteModelUrl;
  }
}

/// Snapshot emitted on [ModelDownloadService.progressStream].
typedef ModelDownloadProgressCallback = void Function(ModelDownloadProgress progress);
