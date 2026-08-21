import 'dart:io';

import 'package:archiveme_mobile/services/offline_tts/offline_tts_config.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_model_contract.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Resolved filesystem paths for an offline TTS voice package.
final class OfflineTtsResolvedPaths {
  const OfflineTtsResolvedPaths({
    required this.modelPath,
    required this.tokensPath,
    this.dataDir = '',
    this.lexiconPath = '',
  });

  final String modelPath;
  final String tokensPath;
  final String dataDir;
  final String lexiconPath;

  OfflineTtsConfig toConfig() {
    return OfflineTtsConfig(
      vitsModelPath: modelPath,
      tokensPath: tokensPath,
      dataDir: dataDir,
      lexiconPath: lexiconPath,
    );
  }
}

/// Locates bundled or sideloaded offline TTS model files on disk.
abstract final class OfflineTtsAssetResolver {
  OfflineTtsAssetResolver._();

  static Future<OfflineTtsResolvedPaths?> resolve({
    String? documentsBasePath,
  }) async {
    final bundled = await _resolveBundledAssets();
    if (bundled != null) {
      return bundled;
    }
    if (documentsBasePath == null || documentsBasePath.isEmpty) {
      return null;
    }
    return _resolveSideloaded(documentsBasePath);
  }

  static Future<OfflineTtsResolvedPaths?> _resolveBundledAssets() async {
    if (!await _assetExists(OfflineTtsModelContract.modelAssetPath) ||
        !await _assetExists(OfflineTtsModelContract.tokensAssetPath)) {
      return null;
    }

    final cacheDir = await _bundledCacheDirectory();
    final modelPath = await _materializeAsset(
      OfflineTtsModelContract.modelAssetPath,
      p.join(cacheDir.path, 'model.onnx'),
    );
    final tokensPath = await _materializeAsset(
      OfflineTtsModelContract.tokensAssetPath,
      p.join(cacheDir.path, 'tokens.txt'),
    );

    return OfflineTtsResolvedPaths(
      modelPath: modelPath,
      tokensPath: tokensPath,
    );
  }

  static Future<OfflineTtsResolvedPaths?> _resolveSideloaded(
    String documentsBasePath,
  ) async {
    final root = Directory(
      p.join(documentsBasePath, OfflineTtsModelContract.sideloadDirectoryName),
    );
    final model = File(
      p.join(root.path, OfflineTtsModelContract.sideloadModelFileName),
    );
    final tokens = File(
      p.join(root.path, OfflineTtsModelContract.sideloadTokensFileName),
    );
    if (!await model.exists() || !await tokens.exists()) {
      return null;
    }

    final espeakDir = Directory(
      p.join(root.path, OfflineTtsModelContract.sideloadEspeakDirName),
    );
    return OfflineTtsResolvedPaths(
      modelPath: model.path,
      tokensPath: tokens.path,
      dataDir: await espeakDir.exists() ? espeakDir.path : '',
    );
  }

  static Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_, stackTrace) {
      return false;
    }
  }

  static Future<Directory> _bundledCacheDirectory() async {
    final dir = Directory(
      p.join(
        Directory.systemTemp.path,
        'archiveme_offline_tts',
      ),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> _materializeAsset(
    String assetPath,
    String destinationPath,
  ) async {
    final destination = File(destinationPath);
    if (await destination.exists()) {
      return destination.path;
    }
    final bytes = await rootBundle.load(assetPath);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return destination.path;
  }
}