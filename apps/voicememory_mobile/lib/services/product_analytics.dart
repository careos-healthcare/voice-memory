import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../config/archive_me_demo_state.dart';
import '../config/creator_demo_mode.dart';
import '../push/firebase_bootstrap.dart';

/// Production analytics — Firebase Analytics when configured, debug log in dev.
class ProductAnalytics {
  ProductAnalytics._();

  static FirebaseAnalytics? _analytics;
  static bool _initialized = false;

  /// Counts events suppressed by creator demo mode — test/debug only.
  @visibleForTesting
  static int demoSuppressedCount = 0;

  /// Call after [FirebaseBootstrap.tryInitialize] (e.g. from [AppServices.initialize]).
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // Creator demo mode: no production analytics collection at all.
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) return;
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductAnalytics: Firebase Analytics unavailable — $e');
      }
      _analytics = null;
    }
  }

  /// Logs a product event. [parameters] values must be strings or numbers.
  static Future<void> track(
    String event, {
    Map<String, Object>? parameters,
  }) async {
    final sanitized = _sanitizeParameters(parameters);
    // Creator demo mode: events are demo-marked in the debug log only and
    // never sent to production analytics.
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) {
      demoSuppressedCount += 1;
      if (kDebugMode) {
        debugPrint('analytics(demo, not sent):$event $sanitized');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('analytics:$event $sanitized');
    }

    final analytics = _analytics;
    if (analytics == null) return;

    try {
      await analytics.logEvent(
        name: _sanitizeEventName(event),
        parameters: sanitized.isEmpty ? null : sanitized,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductAnalytics: logEvent failed for $event — $e');
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
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleaned.length <= 40) return cleaned;
    return cleaned.substring(0, 40);
  }

  static Map<String, Object> _sanitizeParameters(Map<String, Object>? raw) {
    if (raw == null || raw.isEmpty) return {};
    final out = <String, Object>{};
    for (final entry in raw.entries) {
      final key = entry.key.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9_]'),
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
  }
}
