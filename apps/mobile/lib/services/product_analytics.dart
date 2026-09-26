import 'dart:convert';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_event_registry.dart';
import 'package:archiveme_mobile/features/beta_analytics/product_analytics_consent_store.dart';
import 'package:archiveme_mobile/services/proof_analytics_guard.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Production analytics — aggregate event names only, posted server-side.
///
/// Payloads stay on device. The server stores a daily count for the event
/// name and nothing else.
class ProductAnalytics {
  ProductAnalytics._();

  static bool _initialized = false;

  /// Test hook. Production posts the event name to the API.
  @visibleForTesting
  static Future<void> Function(String eventName)? debugTransport;

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

  /// [consentStore] is required in practice — the fallback exists only for the
  /// handful of call sites that run before `AppServices.instance` is readable,
  /// and it resolves to "no consent", which keeps collection off.
  static Future<void> initialize({
    ProductAnalyticsConsentStore? consentStore,
  }) async {
    if (_initialized) return;
    _initialized = true;
    if (ThoughtprintDemoState.isActive || CreatorDemoMode.isActive) return;
    try {
      _consentGranted = await (consentStore?.isGrantedNow() ??
          Future.value(false));
    } catch (e) {
      _consentGranted = false;
      if (kDebugMode) {
        AppLogger.debug('ProductAnalytics: consent read failed — $e');
      }
    }
  }

  /// Records the consent decision locally. Nothing is posted while this is false.
  static Future<void> applyConsent({required bool granted}) async {
    _consentGranted = granted;
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
    if (ThoughtprintDemoState.isActive || CreatorDemoMode.isActive) {
      demoSuppressedCount += 1;
      if (kDebugMode) {
        AppLogger.debug('analytics(demo, not sent):$event $sanitized');
      }
      return;
    }
    if (kDebugMode) {
      AppLogger.debug('analytics:$event $sanitized');
    }

    // Nothing leaves the device without a recorded consent decision, and the
    // request body is the event name only.
    if (!_consentGranted) return;

    try {
      await _postAggregate(_sanitizeEventName(event));
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug('ProductAnalytics: aggregate post failed for $event — $e');
      }
    }
  }

  static Future<void> _postAggregate(String eventName) async {
    final override = debugTransport;
    if (override != null) {
      await override(eventName);
      return;
    }
    final base = AppConfig.apiBaseUrl.trim();
    if (base.isEmpty) return;
    final uri = Uri.parse('$base/api/metrics/product-events');
    await http
        .post(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'event': eventName}),
        )
        .timeout(const Duration(seconds: 5));
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
    _initialized = false;
    _consentGranted = false;
    debugTransport = null;
  }
}