import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Resolves API base URL for [AppConfig.initApiResolution].
///
/// Priority:
/// 1. `--dart-define=BACKEND_URL=...` (then legacy define keys)
/// 2. `.env` file (`BACKEND_URL`, `VOICE_MEMORY_API_BASE_URL`, or `API_BASE_URL`)
/// 3. `config/backend_url.txt` (project file or bundled asset)
class BackendUrlResolver {
  BackendUrlResolver._();

  static const String backendUrlDefineKey = 'BACKEND_URL';
  static const String primaryDefineKey = 'VOICE_MEMORY_API_BASE_URL';
  static const String legacyDefineKey = 'API_BASE_URL';

  static const List<String> _envKeys = [
    backendUrlDefineKey,
    primaryDefineKey,
    legacyDefineKey,
  ];

  static const List<String> _envFilePaths = [
    '.env',
    'apps/voicememory_mobile/.env',
  ];

  static const List<String> _configFilePaths = [
    'config/backend_url.txt',
    'apps/voicememory_mobile/config/backend_url.txt',
  ];

  static const String _assetConfigPath = 'config/backend_url.txt';

  /// Returns normalized base URL or null if none found.
  static Future<String?> resolve() async {
    final fromDefine = _fromDartDefines();
    if (fromDefine != null) {
      _logSource('dart-define', fromDefine);
      return fromDefine;
    }

    final fromEnv = await _fromEnvFile();
    if (fromEnv != null) {
      _logSource('.env', fromEnv);
      return fromEnv;
    }

    final fromConfig = await _fromFallbackConfigFile();
    if (fromConfig != null) {
      _logSource('config/backend_url.txt', fromConfig);
      return fromConfig;
    }

    return null;
  }

  static String? _fromDartDefines() {
    const backend = String.fromEnvironment(backendUrlDefineKey, defaultValue: '');
    if (backend.trim().isNotEmpty) return _normalize(backend.trim());

    const primary = String.fromEnvironment(primaryDefineKey, defaultValue: '');
    if (primary.trim().isNotEmpty) return _normalize(primary.trim());

    const legacy = String.fromEnvironment(legacyDefineKey, defaultValue: '');
    if (legacy.trim().isNotEmpty) return _normalize(legacy.trim());

    return null;
  }

  static Future<String?> _fromEnvFile() async {
    if (kIsWeb) return null;

    for (final path in _envFilePaths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final url = _parseEnvContent(await file.readAsString());
        if (url != null) return url;
      } catch (e) {
        debugPrint('BackendUrlResolver: could not read $path — $e');
      }
    }
    return null;
  }

  static String? _parseEnvContent(String content) {
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      if (!_envKeys.contains(key)) continue;
      var value = trimmed.substring(eq + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      if (value.isNotEmpty) return _normalize(value);
    }
    return null;
  }

  static Future<String?> _fromFallbackConfigFile() async {
    if (!kIsWeb) {
      for (final path in _configFilePaths) {
        try {
          final file = File(path);
          if (!await file.exists()) continue;
          final url = _readConfigLine(await file.readAsString());
          if (url != null) return url;
        } catch (e) {
          debugPrint('BackendUrlResolver: could not read $path — $e');
        }
      }
    }

    try {
      final asset = await rootBundle.loadString(_assetConfigPath);
      return _readConfigLine(asset);
    } catch (_) {
      return null;
    }
  }

  static String? _readConfigLine(String content) {
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      return _normalize(trimmed);
    }
    return null;
  }

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static void _logSource(String source, String url) {
    if (kDebugMode) {
      debugPrint('AppConfig: API base from $source → $url');
    }
  }
}
