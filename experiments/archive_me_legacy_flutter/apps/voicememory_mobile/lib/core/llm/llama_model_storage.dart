import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../storage/app_storage_paths.dart';
import 'llama_model_state.dart';

typedef ModelSupportDirectoryProvider = Future<Directory> Function();

abstract interface class LlamaModelPlatformStorage {
  Future<int> availableBytes(String path);

  Future<void> excludeFromBackup(String path);
}

final class NativeLlamaModelPlatformStorage
    implements LlamaModelPlatformStorage {
  NativeLlamaModelPlatformStorage({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'archive_me/model_storage';
  static const minimumAvailableBytes = 2 * 1024 * 1024 * 1024;

  final MethodChannel _channel;

  @override
  Future<int> availableBytes(String path) async {
    final value = await _channel.invokeMethod<int>('availableBytes', {
      'path': path,
    });
    if (value == null || value < 0) {
      throw const FormatException('Invalid native storage result.');
    }
    return value;
  }

  @override
  Future<void> excludeFromBackup(String path) =>
      _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
}

final class LlamaModelStorage {
  LlamaModelStorage({ModelSupportDirectoryProvider? supportDirectory})
    : _supportDirectory =
          supportDirectory ?? AppStoragePaths.applicationSupportDirectory;

  final ModelSupportDirectoryProvider _supportDirectory;

  static String safeModelId(String id) {
    final safe = id
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^[_\.-]+|[_\.-]+$'), '');
    if (safe.isEmpty || safe == '.' || safe == '..') {
      throw ArgumentError.value(id, 'id', 'Model id has no safe characters.');
    }
    return safe;
  }

  Future<Directory> modelDirectory(String modelId) async {
    final support = await _supportDirectory();
    return Directory(p.join(support.path, 'llm_models', safeModelId(modelId)));
  }

  Future<File> partialFile(String modelId) async =>
      File(p.join((await modelDirectory(modelId)).path, 'model.gguf.part'));

  Future<File> installedFile(String modelId) async =>
      File(p.join((await modelDirectory(modelId)).path, 'model.gguf'));

  Future<File> stateFile(String modelId) async =>
      File(p.join((await modelDirectory(modelId)).path, 'state.json'));

  Future<File> manifestFile(String modelId) async =>
      File(p.join((await modelDirectory(modelId)).path, 'manifest.json'));

  Future<String> relativeDirectory(String modelId) async =>
      p.join('llm_models', safeModelId(modelId));

  Future<void> ensureModelDirectory(String modelId) async {
    final directory = await modelDirectory(modelId);
    if (!await directory.exists()) await directory.create(recursive: true);
  }

  Future<LlamaModelState?> readState(String modelId) async {
    final json = await _readJson(await stateFile(modelId));
    if (json == null ||
        json['schemaVersion'] != LlamaModelState.schemaVersion) {
      return null;
    }
    try {
      return LlamaModelState.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> writeState(String modelId, LlamaModelState state) =>
      _writeAtomicJson(awaited: stateFile(modelId), value: state.toJson());

  Future<Map<String, dynamic>?> readManifest(String modelId) async =>
      _readJson(await manifestFile(modelId));

  Future<void> writeManifest(String modelId, Map<String, dynamic> manifest) =>
      _writeAtomicJson(awaited: manifestFile(modelId), value: manifest);

  Future<void> promotePartial(String modelId) async {
    final partial = await partialFile(modelId);
    final installed = await installedFile(modelId);
    final backup = File('${installed.path}.previous');
    if (await backup.exists()) await backup.delete();
    if (await installed.exists()) await installed.rename(backup.path);
    try {
      await partial.rename(installed.path);
      if (await backup.exists()) await backup.delete();
    } on Object {
      if (await backup.exists() && !await installed.exists()) {
        await backup.rename(installed.path);
      }
      rethrow;
    }
  }

  Future<void> removeModel(String modelId) async {
    final directory = await modelDirectory(modelId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> removeAll() async {
    final support = await _supportDirectory();
    final root = Directory(p.join(support.path, 'llm_models'));
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } on Object {
      return null;
    }
  }

  Future<void> _writeAtomicJson({
    required Future<File> awaited,
    required Map<String, dynamic> value,
  }) async {
    final file = await awaited;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }
}
