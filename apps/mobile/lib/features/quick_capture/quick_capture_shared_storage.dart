import 'dart:convert';

import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_widget_bridge.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// App Group / shared-preferences extension for widget-authored captures.
///
/// Native widgets write JSON payloads; Flutter ingests them into the drift
/// outbox on startup or background wake. Falls back to [MobilePrefsStore]
/// when the platform channel is unavailable (tests, desktop).
class QuickCaptureSharedStorage {
  QuickCaptureSharedStorage({
    required QuickCaptureWidgetBridge bridge,
    required MobilePrefsStore prefs,
  }) : _bridge = bridge,
       _prefs = prefs;

  static const sharedQueueKey = 'quick_capture_shared_queue_v1';
  static const pendingRouteKey = 'quick_capture_widget_pending_route';

  final QuickCaptureWidgetBridge _bridge;
  final MobilePrefsStore _prefs;

  Future<List<QuickCaptureOutboxPayload>> readPendingCaptures() async {
    final fromNative = await _bridge.readPendingCaptures();
    if (fromNative.isNotEmpty) {
      return _parseMaps(fromNative);
    }
    return _readPrefsFallback();
  }

  Future<void> acknowledgeCaptureIds(List<String> captureIds) async {
    if (captureIds.isEmpty) return;
    await _bridge.acknowledgeCaptureIds(captureIds);
    await _removeFromPrefsFallback(captureIds);
  }

  Future<void> enqueueLocalFallback(QuickCaptureOutboxPayload payload) async {
    final existing = await _readPrefsFallback();
    final merged = [
      ...existing.where((item) => item.captureId != payload.captureId),
      payload,
    ];
    await _prefs.writeString(
      sharedQueueKey,
      jsonEncode(merged.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> savePendingLaunchRoute(String route) async {
    await _prefs.writeString(pendingRouteKey, route.trim());
  }

  Future<String?> loadPendingLaunchRoute() async {
    final bridgeRoute = await _bridge.consumePendingLaunchRoute();
    if (bridgeRoute.isNotEmpty) {
      await savePendingLaunchRoute(bridgeRoute);
      return bridgeRoute;
    }
    final route = await _prefs.readString(pendingRouteKey);
    if (route == null || route.trim().isEmpty) return null;
    return route.trim();
  }

  Future<void> clearPendingLaunchRoute() async {
    await _prefs.writeString(pendingRouteKey, '');
  }

  Future<void> _removeFromPrefsFallback(List<String> captureIds) async {
    final existing = await _readPrefsFallback();
    if (existing.isEmpty) return;
    final ids = captureIds.toSet();
    final remaining =
        existing.where((item) => !ids.contains(item.captureId)).toList();
    if (remaining.isEmpty) {
      await _prefs.writeString(sharedQueueKey, '[]');
      return;
    }
    await _prefs.writeString(
      sharedQueueKey,
      jsonEncode(remaining.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<QuickCaptureOutboxPayload>> _readPrefsFallback() async {
    final raw = await _prefs.readString(sharedQueueKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return _parseMaps(
        decoded.whereType<Map>().map(Map<String, dynamic>.from).toList(),
      );
    } on Object {
      return const [];
    }
  }

  List<QuickCaptureOutboxPayload> _parseMaps(
    List<Map<String, dynamic>> maps,
  ) {
    return maps
        .map(QuickCaptureOutboxPayload.fromJson)
        .where((payload) => payload.captureId.isNotEmpty && payload.isValid)
        .toList(growable: false);
  }
}
