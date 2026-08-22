import 'dart:async';

import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_event_registry.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_milestone_store.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_payload_validator.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/services/proof_analytics_guard.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Single production entry point for focused-beta analytics events.
abstract final class BetaAnalyticsTracker {
  BetaAnalyticsTracker._();

  static MobilePrefsStore? _prefs;
  static BetaAnalyticsMilestoneStore? _milestones;
  static void Function(String event, Map<String, Object> payload)? _testSink;

  static final List<({String event, Map<String, Object> payload})> _localLog =
      [];

  @visibleForTesting
  static List<({String event, Map<String, Object> payload})> get localLog =>
      List.unmodifiable(_localLog);

  static void configure(MobilePrefsStore prefs) {
    _prefs = prefs;
    _milestones = BetaAnalyticsMilestoneStore(prefs);
  }

  @visibleForTesting
  static void captureForTest(
    void Function(String event, Map<String, Object> payload) sink,
  ) {
    _testSink = sink;
  }

  @visibleForTesting
  static void resetForTest() {
    _testSink = null;
    _localLog.clear();
    BetaAnalyticsPayloadValidator.resetForTest();
    ProofAnalyticsGuard.resetForTest();
  }

  /// Tracks a registry event after schema validation.
  ///
  /// Never throws. Returns false when the event was refused.
  static Future<bool> track(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) {
      return false;
    }

    final def = BetaAnalyticsEventRegistry.definitionFor(eventName);
    if (def == null) return false;

    final validated = BetaAnalyticsPayloadValidator.validate(
      eventName,
      parameters,
    );
    if (validated == null) return false;

    final sanitized = ProofAnalyticsGuard.sanitize(eventName, validated);

    _localLog.add((event: def.name, payload: Map.unmodifiable(sanitized)));

    final sink = _testSink;
    if (sink != null) {
      sink(def.name, Map.unmodifiable(sanitized));
      return true;
    }

    if (kDebugMode) {
      AppLogger.debug('beta_analytics:${def.name} $sanitized');
    }

    unawaited(ProductAnalytics.track(def.name, parameters: sanitized));
    return true;
  }

  /// Tracks a once-per-install event, persisting emission in local prefs.
  static Future<bool> trackOnce(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    final store = _milestones;
    if (store == null) {
      return track(eventName, parameters: parameters);
    }

    var shouldEmit = false;
    await store.update((current) {
      if (current.hasEmitted(eventName)) return current;
      shouldEmit = true;
      return current.markEmitted(eventName);
    });

    if (!shouldEmit) return false;
    return track(eventName, parameters: parameters);
  }

  static BetaAnalyticsMilestoneStore? get milestoneStore => _milestones;
}
