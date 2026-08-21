import 'dart:io';

import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_model_contract.dart';
import 'package:archiveme_mobile/services/local_llm/model_download_service.dart';
import 'package:path/path.dart' as p;

/// Resolved filesystem path for a local GGUF model package.
final class LocalLlmResolvedModel {
  const LocalLlmResolvedModel({required this.modelPath});

  final String modelPath;

  LocalLlmConfig toConfig({
    String? libraryPath,
    bool requirePreferred = true,
    bool useChatMlFormat = true,
    int? maxTokens,
  }) {
    return LocalLlmConfig.mobile(
      modelPath: modelPath,
      libraryPath: libraryPath,
      requirePreferredQuantization: requirePreferred,
      useChatMlFormat: useChatMlFormat,
      maxTokens: maxTokens ?? LocalLlmModelContract.defaultMaxTokens,
    );
  }
}

/// Locates downloaded or sideloaded Q4_K_M GGUF models on disk.
abstract final class LocalLlmAssetResolver {
  LocalLlmAssetResolver._();

  static Future<LocalLlmResolvedModel?> resolve({
    ModelDownloadService? modelDownloadService,
    String? documentsBasePath,
    String? modelPathOverride,
  }) async {
    if (modelPathOverride != null &&
        modelPathOverride.isNotEmpty &&
        await File(modelPathOverride).exists()) {
      if (LocalLlmModelContract.isHeavilyQuantizedGguf(modelPathOverride)) {
        return LocalLlmResolvedModel(modelPath: modelPathOverride);
      }
      return null;
    }

    final downloadedPath = await modelDownloadService?.modelFilePath();
    if (downloadedPath != null) {
      return LocalLlmResolvedModel(modelPath: downloadedPath);
    }

    return _resolveSideloaded(documentsBasePath);
  }

  static Future<LocalLlmResolvedModel?> _resolveSideloaded(
    String? documentsBasePath,
  ) async {
    if (documentsBasePath == null || documentsBasePath.isEmpty) {
      return null;
    }

    final root = Directory(
      p.join(documentsBasePath, LocalLlmModelContract.sideloadDirectoryName),
    );
    if (!await root.exists()) {
      return null;
    }

    final preferred = File(
      p.join(root.path, LocalLlmModelContract.sideloadModelFileName),
    );
    if (await preferred.exists() &&
        LocalLlmModelContract.isHeavilyQuantizedGguf(preferred.path)) {
      return LocalLlmResolvedModel(modelPath: preferred.path);
    }

    final matches = <File>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (LocalLlmModelContract.isHeavilyQuantizedGguf(entity.path)) {
        matches.add(entity);
      }
    }
    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) => a.path.compareTo(b.path));
    final preferredMatch = matches.firstWhere(
      (file) => LocalLlmModelContract.matchesPreferredQuantization(file.path),
      orElse: () => matches.first,
    );
    return LocalLlmResolvedModel(modelPath: preferredMatch.path);
  }
}
