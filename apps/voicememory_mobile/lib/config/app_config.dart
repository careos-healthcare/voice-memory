import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'backend_url_resolver.dart';
import 'developer_settings_gate.dart';
import '../storage/app_storage_paths.dart';

/// Backend base URL — set at build/run time (never hardcode secrets here).
///
/// ```bash
/// # Physical device (use your machine's LAN IP or production host):
/// flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://192.168.1.10:3000
/// # or legacy:
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
///
/// # Android emulator (no define needed — uses 10.0.2.2:3000 automatically)
/// flutter run
/// ```
class AppConfig {
  AppConfig._();

  static const String appName = 'ArchiveMe';
  static const String bundleId = 'com.voicememory.app';

  /// Production Next.js API (Vercel). `careosapp.co.uk` is marketing-only and
  /// does not serve `/api/*` — do not point mobile captures at that host.
  static const String productionApiBaseUrl =
      'https://voice-memory-iota.vercel.app';

  static const String stagingApiBaseUrl =
      'https://voice-memory-iota.vercel.app';

  static const String defaultDevBaseUrl = 'http://127.0.0.1:3000';

  static const String defaultAndroidEmulatorBaseUrl = 'http://10.0.2.2:3000';

  /// Highest-priority dart-define: `--dart-define=BACKEND_URL=...`
  static const String backendUrlDefineKey =
      BackendUrlResolver.backendUrlDefineKey;

  /// Primary dart-define key (preferred).
  static const String apiBaseUrlDefineKey = 'VOICE_MEMORY_API_BASE_URL';

  /// Legacy alias (required on physical devices when primary is unset).
  static const String legacyApiBaseUrlDefineKey = 'API_BASE_URL';

  static const String backendNotConfiguredMessage =
      'Backend URL not configured';

  static bool _releaseApiWarningLogged = false;
  static bool _apiResolutionInitialized = false;
  static String? _resolvedApiBase;
  static bool _backendConfigured = true;

  static bool get isReleaseBuild => kReleaseMode;

  /// Debug/profile IDE builds and `VM_DEBUG_TOOLS` dart-define.
  static bool get isDebugBuild => kDebugMode || _debugToolsFromEnvironment;

  static bool get isBackendConfigured => _apiResolutionInitialized
      ? _backendConfigured
      : _urlFromDartDefinesSync() != null;

  static bool get isApiResolutionInitialized => _apiResolutionInitialized;

  /// Call once at startup before [AppServices.initialize].
  static Future<void> initApiResolution() async {
    if (_apiResolutionInitialized) return;

    final resolved = await BackendUrlResolver.resolve();
    if (resolved != null) {
      _resolvedApiBase = resolved;
      _backendConfigured = true;
      _apiResolutionInitialized = true;
      _warnReleaseApiConfigIfNeeded(resolved);
      return;
    }

    if (kReleaseMode) {
      _resolvedApiBase = productionApiBaseUrl;
      _backendConfigured = true;
      _apiResolutionInitialized = true;
      _warnReleaseApiConfigIfNeeded(productionApiBaseUrl);
      return;
    }

    if (kIsWeb) {
      _resolvedApiBase = defaultDevBaseUrl;
      _backendConfigured = true;
      _apiResolutionInitialized = true;
      return;
    }

    if (AppStoragePaths.isIosDebugSimulator()) {
      _resolvedApiBase = defaultDevBaseUrl;
      _backendConfigured = true;
      _apiResolutionInitialized = true;
      debugPrint('AppConfig: debug API base → $_resolvedApiBase (iOS simulator)');
      return;
    }

    final physical = await _isPhysicalDevice();
    if (!physical) {
      _resolvedApiBase = Platform.isAndroid
          ? defaultAndroidEmulatorBaseUrl
          : defaultDevBaseUrl;
      _backendConfigured = true;
      _apiResolutionInitialized = true;
      debugPrint('AppConfig: debug API base → $_resolvedApiBase');
      return;
    }

    _resolvedApiBase = productionApiBaseUrl;
    _backendConfigured = true;
    _apiResolutionInitialized = true;
    debugPrint(
      'AppConfig: no BACKEND_URL in defines, .env, or config/backend_url.txt — '
      'using production fallback ($productionApiBaseUrl). '
      'Override with --dart-define=$backendUrlDefineKey=http://YOUR_LAN_IP:3000',
    );
  }

  static Future<bool> _isPhysicalDevice() async {
    final info = await DeviceInfoPlugin().deviceInfo;
    return switch (info) {
      AndroidDeviceInfo android => android.isPhysicalDevice,
      IosDeviceInfo ios => ios.isPhysicalDevice,
      _ => true,
    };
  }

  static bool _isLocalhostUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('127.0.0.1') ||
        u.contains('localhost') ||
        u.contains('10.0.2.2');
  }

  static void _warnReleaseApiConfigIfNeeded(String resolvedUrl) {
    if (!kReleaseMode || _releaseApiWarningLogged) return;
    _releaseApiWarningLogged = true;
    if (!isReleaseApiConfigured) {
      debugPrint(
        '*** ArchiveMe RELEASE BUILD: $apiBaseUrlDefineKey is not set — '
        'using $productionApiBaseUrl. Pass --dart-define=$apiBaseUrlDefineKey=... ***',
      );
    }
    if (_isLocalhostUrl(resolvedUrl)) {
      debugPrint(
        '*** ArchiveMe RELEASE BUILD: API base URL is localhost/emulator ($resolvedUrl) — '
        'pass --dart-define=$apiBaseUrlDefineKey=https://your-production-host ***',
      );
    }
  }

  /// Sync dart-define lookup (before async [.env] / config file resolution).
  static String? _urlFromDartDefinesSync() {
    const backend = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (backend.trim().isNotEmpty) return _normalizeBase(backend.trim());
    const primary = String.fromEnvironment(
      apiBaseUrlDefineKey,
      defaultValue: '',
    );
    if (primary.trim().isNotEmpty) return _normalizeBase(primary.trim());
    const legacy = String.fromEnvironment(
      legacyApiBaseUrlDefineKey,
      defaultValue: '',
    );
    if (legacy.trim().isNotEmpty) return _normalizeBase(legacy.trim());
    return null;
  }

  static String get apiBaseUrl {
    if (_resolvedApiBase != null && _resolvedApiBase!.isNotEmpty) {
      return _resolvedApiBase!;
    }
    final fromDefine = _urlFromDartDefinesSync();
    if (fromDefine != null) return fromDefine;
    if (kReleaseMode) return productionApiBaseUrl;
    if (!_apiResolutionInitialized) {
      return Platform.isAndroid
          ? defaultAndroidEmulatorBaseUrl
          : defaultDevBaseUrl;
    }
    return '';
  }

  static bool get isReleaseApiConfigured {
    return _urlFromDartDefinesSync() != null;
  }

  static bool get looksLikeLocalhost => _isLocalhostUrl(apiBaseUrl);

  static String _normalizeBase(String url) =>
      BackendUrlResolver.normalizeApiBaseUrl(url);

  /// User-facing hint for Native Push Verify and settings.
  static String get apiBaseUrlStatusLabel {
    if (!isBackendConfigured) return backendNotConfiguredMessage;
    return apiBaseUrl.isEmpty ? backendNotConfiguredMessage : apiBaseUrl;
  }

  /// Consumer-facing legal URLs — not the API backend host.
  static const String privacyUrl = 'https://careosapp.co.uk/archiveme-privacy';

  /// In-app terms route (see [TermsScreen]).
  static const String termsRoute = '/terms';
  static const String contactUrl = '$productionApiBaseUrl/contact';
  static const String helpEmail = 'hello@voicememory.app';

  static const bool coreLoopEnabled = true;
  static const bool authImplemented = true;
  static const bool nativeBillingImplemented = true;
  static const bool serverJournalSyncImplemented = true;
  static const bool pushImplemented = true;

  static const String internalDebugToken = String.fromEnvironment(
    'VM_INTERNAL_DEBUG_TOKEN',
    defaultValue: '',
  );

  /// Internal verification screens — gated by [DeveloperSettingsGate].
  static const bool _debugToolsFromEnvironment = bool.fromEnvironment(
    'VM_DEBUG_TOOLS',
    defaultValue: false,
  );

  static bool get debugToolsEnabled => isDebugBuild;

  /// API keys, dart-defines, tokens, and verification JSON — developer gate only.
  static bool get showInternalVerificationDetails =>
      DeveloperSettingsGate.canShowInternalVerificationDetails;

  static const bool resurfacingImplemented = true;

  static const int patternReviewReflectionTarget = 5;

  /// GPT-5 Archive Synthesis pilot — parallel monthly review layer.
  static const bool enableGpt5ArchiveSynthesis = bool.fromEnvironment(
    'ENABLE_GPT5_ARCHIVE_SYNTHESIS',
    defaultValue: false,
  );
}
