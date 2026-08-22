import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show AppServices;
import 'package:archiveme_mobile/push/firebase_bootstrap.dart';
import 'package:archiveme_mobile/services/app_services.dart' show AppServices;
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_event_registry.dart';
import 'package:archiveme_mobile/features/beta_analytics/product_analytics_consent_store.dart';
import 'package:archiveme_mobile/services/proof_analytics_guard.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Production analytics — Firebase Analytics when configured, debug log in dev.
class ProductAnalytics {
  ProductAnalytics._();

  static FirebaseAnalytics? _analytics;
  static bool _initialized = false;

  /// Whether the customer has affirmatively allowed collection.
  ///
  /// Starts `false` and is only ever set from a recorded
  /// [ProductAnalyticsConsentState]. Nothing reaches the provider while this is
  /// false, so a failure to read consent cannot become permission to collect.
  static bool _consentGranted = false;

  /// Counts events suppressed by creator demo mode — test/debug only.
  @visibleForTesting
  static int demoSuppressedCount = 0;

  @visibleForTesting
  static bool get consentGranted => _consentGranted;

  /// Call after [FirebaseBootstrap.tryInitialize] (e.g. from [AppServices.initialize]).
  ///
  /// [consentStore] is required in practice — the fallback exists only for the
  /// handful of call sites that run before `AppServices.instance` is readable,
  /// and it resolves to "no consent", which keeps collection off.
  static Future<void> initialize({
    ProductAnalyticsConsentStore? consentStore,
  }) async {
    if (_initialized) return;
    _initialized = true;
    // Creator demo mode: no production analytics collection at all.
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) return;
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      await applyConsent(
        granted: await (consentStore?.isGrantedNow() ?? Future.value(false)),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        AppLogger.debug('ProductAnalytics: Firebase Analytics unavailable — $e');
      }
      _analytics = null;
      _consentGranted = false;
    }
  }

  /// Applies an analytics consent decision to the provider and to this facade.
  ///
  /// Always calls through to the provider, including with `false`. Firebase
  /// enables collection by default from the platform manifest, so declining has
  /// to be stated explicitly — simply not calling would leave collection on.
  static Future<void> applyConsent({required bool granted}) async {
    _consentGranted = granted;
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.setAnalyticsCollectionEnabled(granted);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug('ProductAnalytics: consent apply failed — $e');
      }
      // The provider state is now unknown, so stop sending from our side too.
      _consentGranted = false;
    }
  }

  /// Logs a product event. [parameters] values must be strings or numbers.
  static Future<void> track(
    String event, {
    Map<String, Object>? parameters,
  }) async {
    // Production graph: only focused-beta registry events may reach Firebase.
    if (!BetaAnalyticsEventRegistry.isProductionEvent(event)) {
      if (kDebugMode) {
        AppLogger.debug('ProductAnalytics: dropped unregistered event — $event');
      }
      return;
    }

    // Fail-closed privacy guard: runs before anything else touches the
    // payload, so content-bearing attributes never reach the provider.
    final sanitized = _sanitizeParameters(
      ProofAnalyticsGuard.sanitize(event, parameters),
    );
    // Creator demo mode: events are demo-marked in the debug log only and
    // never sent to production analytics.
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) {
      demoSuppressedCount += 1;
      if (kDebugMode) {
        AppLogger.debug('analytics(demo, not sent):$event $sanitized');
      }
      return;
    }
    if (kDebugMode) {
      AppLogger.debug('analytics:$event $sanitized');
    }

    final analytics = _analytics;
    // Second gate, after the debug log so local development still sees the
    // event: nothing leaves the device without a recorded consent decision.
    if (analytics == null || !_consentGranted) return;

    try {
      await analytics.logEvent(
        name: _sanitizeEventName(event),
        parameters: sanitized.isEmpty ? null : sanitized,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        AppLogger.debug('ProductAnalytics: logEvent failed for $event — $e');
      }
    }
  }

  /// Convenience for string-only property maps used across feature analytics.
  static Future<void> trackStrings(
    String event, [
    Map<String, String>? properties,
  ]) {
    if (properties == null || properties.isEmpty) {
      return track(event);
    }
    return track(
      event,
      parameters: {for (final e in properties.entries) e.key: e.value},
    );
  }

  static String _sanitizeEventName(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_]'), '_')
        .replaceAll(RegExp('_+'), '_');
    if (cleaned.length <= 40) return cleaned;
    return cleaned.substring(0, 40);
  }

  static Map<String, Object> _sanitizeParameters(Map<String, Object>? raw) {
    if (raw == null || raw.isEmpty) return {};
    final out = <String, Object>{};
    for (final entry in raw.entries) {
      final key = entry.key.toLowerCase().replaceAll(
        RegExp('[^a-z0-9_]'),
        '_',
      );
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value is String) {
        out[key] = value.length > 100 ? value.substring(0, 100) : value;
      } else if (value is num) {
        out[key] = value;
      } else {
        out[key] = value.toString();
      }
      if (out.length >= 25) break;
    }
    return out;
  }

  @visibleForTesting
  static void resetForTest() {
    _analytics = null;
    _initialized = false;
    _consentGranted = false;
  }
}