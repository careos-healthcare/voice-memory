import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_event.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_snapshot.dart';
import 'package:flutter/foundation.dart';

/// Local-only revenue funnel instrumentation — no network, no user content.
abstract final class RevenueFunnelAnalytics {
  RevenueFunnelAnalytics._();

  static final List<({RevenueFunnelEvent event, Map<String, Object> metadata})>
  _events = [];

  @visibleForTesting
  static List<({RevenueFunnelEvent event, Map<String, Object> metadata})>
  get eventsForTest => recordedEvents;

  static List<({RevenueFunnelEvent event, Map<String, Object> metadata})>
  get recordedEvents => List.unmodifiable(_events);

  static RevenueFunnelSnapshot debugSummary() =>
      RevenueFunnelSnapshot.fromEvents(_events);

  static void firstProofSeen({
    required int entryCount,
    required String source,
    String surface = 'record',
    bool? hasConfirmedRepeat,
  }) {
    _track(
      RevenueFunnelEvent.firstProofSeen,
      entryCount: entryCount,
      source: source,
      surface: surface,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void proLockSeen({
    required int entryCount,
    required String source,
    required bool hasConfirmedRepeat,
    String? surface,
  }) {
    _track(
      RevenueFunnelEvent.proLockSeen,
      entryCount: entryCount,
      source: source,
      surface: surface ?? _surfaceFromSource(source),
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void proLockCtaTapped({
    required int entryCount,
    required String source,
    required bool hasConfirmedRepeat,
    String? surface,
  }) {
    _track(
      RevenueFunnelEvent.proLockCtaTapped,
      entryCount: entryCount,
      source: source,
      surface: surface ?? _surfaceFromSource(source),
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void monthlyReportPreviewSeen({
    required int entryCount,
    required String source,
    required bool hasConfirmedRepeat,
    String? surface,
  }) {
    _track(
      RevenueFunnelEvent.monthlyReportPreviewSeen,
      entryCount: entryCount,
      source: source,
      surface: surface ?? source,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void monthlyReportPreviewCtaTapped({
    required int entryCount,
    required String source,
    required bool hasConfirmedRepeat,
    String? surface,
  }) {
    _track(
      RevenueFunnelEvent.monthlyReportPreviewCtaTapped,
      entryCount: entryCount,
      source: source,
      surface: surface ?? source,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void backupBridgeSeen({
    required int entryCount,
    required String source,
    required bool hasConfirmedRepeat,
    required bool hasReportPreview,
    String? surface,
  }) {
    _track(
      RevenueFunnelEvent.backupBridgeSeen,
      entryCount: entryCount,
      source: source,
      surface: surface ?? source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasReportPreview: hasReportPreview,
    );
  }

  static void backupBridgeCtaTapped({
    required int entryCount,
    required String source,
    required bool hasConfirmedRepeat,
    required bool hasReportPreview,
    String? surface,
  }) {
    _track(
      RevenueFunnelEvent.backupBridgeCtaTapped,
      entryCount: entryCount,
      source: source,
      surface: surface ?? source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasReportPreview: hasReportPreview,
    );
  }

  static void proEvidenceValueSeen({
    required int entryCount,
    required String source,
    String? surface,
  }) {
    _track(
      RevenueFunnelEvent.proEvidenceValueSeen,
      entryCount: entryCount,
      source: source,
      surface: surface ?? _surfaceFromSource(source),
    );
  }

  static void proEvidenceValueCtaTapped({
    required int entryCount,
    required String source,
    String? surface,
    String? actionType,
  }) {
    _track(
      RevenueFunnelEvent.proEvidenceValueCtaTapped,
      entryCount: entryCount,
      source: source,
      surface: surface ?? _surfaceFromSource(source),
    );
  }

  static void paywallSeen({
    required String source,
    required bool isPro,
    int? entryCount,
    String surface = 'paywall_screen',
    bool? hasConfirmedRepeat,
    bool? hasReportPreview,
  }) {
    _track(
      RevenueFunnelEvent.paywallSeen,
      entryCount: entryCount,
      source: source,
      surface: surface,
      isPro: isPro,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasReportPreview: hasReportPreview,
    );
  }

  static void paywallPurchaseCtaTapped({
    required String source,
    required bool isPro,
    int? entryCount,
    String surface = 'paywall_screen',
  }) {
    _track(
      RevenueFunnelEvent.paywallPurchaseCtaTapped,
      entryCount: entryCount,
      source: source,
      surface: surface,
      isPro: isPro,
    );
  }

  static void paywallRestoreTapped({
    required String source,
    required bool isPro,
    int? entryCount,
    String surface = 'paywall_screen',
  }) {
    _track(
      RevenueFunnelEvent.paywallRestoreTapped,
      entryCount: entryCount,
      source: source,
      surface: surface,
      isPro: isPro,
    );
  }

  static void paywallDismissed({
    required String source,
    required bool isPro,
    int? entryCount,
    String surface = 'paywall_screen',
  }) {
    _track(
      RevenueFunnelEvent.paywallDismissed,
      entryCount: entryCount,
      source: source,
      surface: surface,
      isPro: isPro,
    );
  }

  static void _track(
    RevenueFunnelEvent event, {
    int? entryCount,
    String? source,
    bool? hasConfirmedRepeat,
    bool? hasReportPreview,
    bool? isPro,
    String? surface,
  }) {
    final metadata = <String, Object>{
      'entry_count': ?entryCount,
      if (source != null) 'source': _sanitizeId(source),
      if (hasConfirmedRepeat != null)
        'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      if (hasReportPreview != null)
        'has_report_preview': hasReportPreview ? 1 : 0,
      if (isPro != null) 'is_pro': isPro ? 1 : 0,
      if (surface != null) 'surface': _sanitizeId(surface),
    };

    _events.add((event: event, metadata: metadata));

    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_REVENUE_FUNNEL event=${event.id} '
        '${metadata.entries.map((e) => '${e.key}=${e.value}').join(' ')}',
      );
    }
  }

  static String _surfaceFromSource(String source) {
    if (source.startsWith('record')) return 'record';
    return _sanitizeId(source);
  }

  static String _sanitizeId(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return 'unknown';
    final sanitized = trimmed.replaceAll(RegExp('[^a-z0-9_]'), '_');
    return sanitized.length <= 40 ? sanitized : sanitized.substring(0, 40);
  }

  @visibleForTesting
  static void resetForTest() {
    _events.clear();
  }
}