import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../push/firebase_bootstrap.dart';
import 'analytics/analytics_catalog.dart';

typedef AnalyticsProvider =
    Future<void> Function(String event, Map<String, Object> parameters);

typedef _QueuedAnalyticsEvent = ({
  AnalyticsEventId event,
  Map<String, Object> parameters,
});

/// Content-free product analytics facade.
///
/// All paths, including the legacy string API and activation funnel, are
/// converted to catalogued identifiers and validated again immediately before
/// provider dispatch. Invalid payloads throw in debug/test. Release builds drop
/// them and increment [contentFreeRejectionCount].
class ProductAnalytics {
  ProductAnalytics._();

  static FirebaseAnalytics? _analytics;
  static AnalyticsProvider? _provider;
  static bool _initialized = false;
  static final List<_QueuedAnalyticsEvent> _pendingEvents = [];
  static final List<({String event, Map<String, Object> parameters})>
  _eventsForTest = [];

  @visibleForTesting
  static List<({String event, Map<String, Object> parameters})>
  get eventsForTest => List.unmodifiable(_eventsForTest);

  @visibleForTesting
  static int get queuedEventCountForTest => _pendingEvents.length;

  /// Number of payloads rejected locally in release mode.
  static int contentFreeRejectionCount = 0;

  /// Call after [FirebaseBootstrap.tryInitialize] (e.g. from [AppServices.initialize]).
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _provider = _firebaseProvider;
      await _flushPendingEvents();
    } catch (_) {
      if (kDebugMode) {
        debugPrint('ProductAnalytics: Firebase Analytics unavailable');
      }
      _analytics = null;
      _provider = null;
    }
  }

  /// Typed V1 boundary. Event names cannot be supplied by callers.
  static Future<void> track(
    V1AnalyticsEvent event, {
    Map<String, Object?>? parameters,
  }) async {
    await _trackCatalogued(AnalyticsCatalog.v1Event(event), parameters);
  }

  /// Typed operational boundary used by privacy-reviewed feature facades.
  ///
  /// Callers cannot supply an event name. Payloads are validated here and
  /// again in [_dispatch] immediately before crossing the provider boundary.
  static Future<void> trackOperational(
    OperationalAnalyticsEvent event, {
    Map<String, Object?>? parameters,
  }) async {
    await _trackCatalogued(
      AnalyticsCatalog.operationalEvent(event),
      parameters,
    );
  }

  /// Compatibility boundary for [ActivationFunnelAnalytics].
  ///
  /// Activation events are constrained to the catalog's lifecycle event
  /// grammar and still pass through the same final provider guard.
  static Future<void> trackActivation(
    String event, {
    Map<String, Object?>? parameters,
  }) async {
    final eventId = AnalyticsCatalog.activationEvent(event);
    if (eventId == null) {
      _reject('Unknown activation analytics event id "$event".');
      return;
    }
    await _trackCatalogued(eventId, parameters);
  }

  /// Strict content-free pricing-validation boundary.
  ///
  /// Callers provide only catalog enums, a count that is bucketed before
  /// dispatch, and a proof flag. No source, repair-mode, amount, product id,
  /// or free-form property can cross this facade.
  static Future<void> trackPricingValidation({
    required CatalogPricingValidationEvent event,
    required int entryCount,
    required bool hasUsefulProof,
    CatalogPricingValueState? valueState,
    CatalogPricingReason? reason,
  }) {
    return _trackCatalogued(AnalyticsCatalog.pricingValidationEvent(event), {
      'entry_count': entryCount,
      'has_useful_proof': hasUsefulProof,
      if (valueState != null)
        'option_type': AnalyticsCatalog.pricingValueStateToken(valueState),
      if (reason != null) 'reason': AnalyticsCatalog.pricingReasonToken(reason),
    });
  }

  static Future<void> _trackCatalogued(
    AnalyticsEventId event,
    Map<String, Object?>? parameters,
  ) async {
    final serialized = _serializeOrReject(event, parameters);
    if (serialized == null) return;

    if (kDebugMode) {
      debugPrint('analytics:${event.value} ${serialized.parameters}');
    }

    final provider = _provider;
    if (provider == null) {
      if (_pendingEvents.length >= 100) _pendingEvents.removeAt(0);
      _pendingEvents.add(serialized);
      return;
    }
    await _dispatch(provider, serialized);
  }

  /// Convenience for string-only property maps used across feature analytics.
  static Future<void> trackStrings(
    V1AnalyticsEvent event, [
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

  static _QueuedAnalyticsEvent? _serializeOrReject(
    AnalyticsEventId event,
    Map<String, Object?>? raw, {
    bool recordForTest = true,
  }) {
    final out = <String, Object>{};
    for (final entry in (raw ?? const <String, Object?>{}).entries) {
      final originalKey = entry.key;
      if (AnalyticsCatalog.isSensitiveKey(originalKey)) {
        _reject('Sensitive analytics property key "$originalKey".');
        return null;
      }

      final value = entry.value;
      var key = originalKey;
      Object serializedValue;
      if (value is bool) {
        serializedValue = value ? '1' : '0';
      } else if (value is num) {
        key = AnalyticsCatalog.bucketedKey(key);
        if (key == originalKey) {
          final spec = AnalyticsCatalog.propertySpecs[key];
          if (spec?.kind != AnalyticsValueKind.flag ||
              (value != 0 && value != 1)) {
            _reject('Unbounded numeric analytics property "$originalKey".');
            return null;
          }
          serializedValue = value.toInt().toString();
        } else {
          try {
            serializedValue = AnalyticsCatalog.countBucket(value);
          } on ArgumentError {
            _reject('Invalid analytics count "$originalKey".');
            return null;
          }
        }
      } else if (value is String) {
        serializedValue = value;
      } else {
        _reject(
          'Nested, null, or unsupported analytics value for "$originalKey".',
        );
        return null;
      }

      final spec = AnalyticsCatalog.propertySpecs[key];
      if (spec == null) {
        _reject('Unknown analytics property key "$key".');
        return null;
      }
      final stringValue = serializedValue as String;
      if (spec.allowedValues != null &&
          !spec.allowedValues!.contains(stringValue)) {
        _reject('Uncatalogued value for analytics property "$key".');
        return null;
      }
      if (spec.kind == AnalyticsValueKind.token &&
          !AnalyticsCatalog.isSafeToken(stringValue)) {
        _reject('Free-text analytics value for "$key".');
        return null;
      }
      out[key] = stringValue;
    }
    if (out.length > 25) {
      _reject('Analytics payload exceeds 25 properties.');
      return null;
    }

    final immutable = Map<String, Object>.unmodifiable(out);
    if (recordForTest) {
      _eventsForTest.add((event: event.value, parameters: immutable));
    }
    return (event: event, parameters: immutable);
  }

  static Future<void> _dispatch(
    AnalyticsProvider provider,
    _QueuedAnalyticsEvent event,
  ) async {
    // This is the final serialized payload boundary immediately before the
    // provider. It is intentionally revalidated to prevent future queue or
    // breadcrumb code from bypassing the catalog.
    final checked = _serializeProviderPayloadOrReject(event);
    if (checked == null) return;
    try {
      await provider(checked.event.value, checked.parameters);
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          'ProductAnalytics: provider failed for ${checked.event.value}',
        );
      }
    }
  }

  static _QueuedAnalyticsEvent? _serializeProviderPayloadOrReject(
    _QueuedAnalyticsEvent event,
  ) {
    final known =
        AnalyticsCatalog.legacyEvent(event.event.value) ??
        AnalyticsCatalog.activationEvent(event.event.value);
    if (known == null) {
      _reject('Queued analytics event is not catalogued.');
      return null;
    }
    return _serializeOrReject(known, event.parameters, recordForTest: false);
  }

  static Future<void> _firebaseProvider(
    String event,
    Map<String, Object> parameters,
  ) async {
    final analytics = _analytics;
    if (analytics == null) return;
    await analytics.logEvent(
      name: event,
      parameters: parameters.isEmpty ? null : parameters,
    );
  }

  static Future<void> _flushPendingEvents() async {
    final provider = _provider;
    if (provider == null || _pendingEvents.isEmpty) return;
    final queued = List<_QueuedAnalyticsEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in queued) {
      await _dispatch(provider, event);
    }
  }

  static void _reject(String reason) {
    if (kDebugMode) {
      throw StateError('Content-free analytics rejected: $reason');
    }
    contentFreeRejectionCount += 1;
  }

  /// Clears queued analytics and resets Firebase's installation analytics
  /// identity. Used for both account deletion and a local privacy wipe.
  static Future<void> resetIdentityAndQueue() async {
    _pendingEvents.clear();
    _eventsForTest.clear();
    final analytics = _analytics;
    _provider = null;
    _analytics = null;
    _initialized = false;
    if (analytics != null) {
      try {
        await analytics.resetAnalyticsData();
      } catch (_) {
        if (kDebugMode) {
          debugPrint('ProductAnalytics: analytics identity reset failed');
        }
      }
    }
  }

  @visibleForTesting
  static void installProviderForTest(AnalyticsProvider provider) {
    _provider = provider;
    unawaited(_flushPendingEvents());
  }

  @visibleForTesting
  static void resetForTest() {
    _analytics = null;
    _provider = null;
    _initialized = false;
    _pendingEvents.clear();
    _eventsForTest.clear();
    contentFreeRejectionCount = 0;
  }
}
