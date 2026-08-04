import 'dart:convert';

import '../billing/paywall_attribution_store.dart';
import '../billing/suggestion_attribution_store.dart';
import '../features/beta/archive_activation_funnel_store.dart';
import '../features/beta/beta_activation_loop_store.dart';
import '../features/beta_activation/beta_activation_summary_store.dart';
import '../features/retention/retention_metrics_tracker.dart';
import '../services/app_services.dart';

/// A user-requested export containing only explicitly allowlisted local logs.
class BehavioralLogExportArtifact {
  const BehavioralLogExportArtifact({
    required this.contents,
    required this.exportedAt,
    required this.eventCount,
  });

  final String contents;
  final DateTime exportedAt;
  final int eventCount;

  bool get isEmpty => eventCount == 0;

  String get filename {
    final day = exportedAt.toUtc().toIso8601String().split('T').first;
    return 'archiveme_behavioral_logs_$day.json';
  }
}

/// Builds and clears the small, local-only behavioral log allowlist.
///
/// This service never reads the full preferences map. Adding another category
/// requires an explicit store dependency and serializer here.
class BehavioralLogExportService {
  BehavioralLogExportService({
    required PaywallAttributionStore paywallStore,
    required SuggestionAttributionStore suggestionStore,
    ArchiveActivationFunnelStore? archiveActivationStore,
    RetentionMetricsStore? retentionMetricsStore,
    BetaActivationSummaryStore? betaActivationSummaryStore,
    BetaActivationLoopStore? betaActivationLoopStore,
    DateTime Function()? now,
  }) : // Public named parameters cannot expose private field names.
       // ignore: prefer_initializing_formals
       _paywallStore = paywallStore,
       // ignore: prefer_initializing_formals
       _suggestionStore = suggestionStore,
       // ignore: prefer_initializing_formals
       _archiveActivationStore = archiveActivationStore,
       // ignore: prefer_initializing_formals
       _retentionMetricsStore = retentionMetricsStore,
       // ignore: prefer_initializing_formals
       _betaActivationSummaryStore = betaActivationSummaryStore,
       // ignore: prefer_initializing_formals
       _betaActivationLoopStore = betaActivationLoopStore,
       _now = now ?? DateTime.now;

  final PaywallAttributionStore _paywallStore;
  final SuggestionAttributionStore _suggestionStore;
  final ArchiveActivationFunnelStore? _archiveActivationStore;
  final RetentionMetricsStore? _retentionMetricsStore;
  final BetaActivationSummaryStore? _betaActivationSummaryStore;
  final BetaActivationLoopStore? _betaActivationLoopStore;
  final DateTime Function() _now;

  static const int schemaVersion = 2;

  static BehavioralLogExportService instance() => BehavioralLogExportService(
    paywallStore: PaywallAttributionStore.instance(),
    suggestionStore: SuggestionAttributionStore.instance(),
    archiveActivationStore: ArchiveActivationFunnelStore(
      AppServices.instance.prefs,
    ),
    retentionMetricsStore: RetentionMetricsStore.instance(),
    betaActivationSummaryStore: BetaActivationSummaryStore.fromAppServices(),
    betaActivationLoopStore: BetaActivationLoopStore.fromAppServices(),
  );

  Future<BehavioralLogExportArtifact> buildExport() async {
    final exportedAt = _now().toUtc();
    final paywall = await _paywallStore.exportRecords(now: exportedAt);
    final suggestions = await _suggestionStore.exportRecords(now: exportedAt);
    final archiveActivation =
        await _archiveActivationStore?.exportAggregateCounts() ??
        const <String, int>{};
    final retention =
        await _retentionMetricsStore?.exportAggregateCounts() ??
        const <String, int>{};
    final betaSummary =
        await _betaActivationSummaryStore?.exportAggregateCounts() ??
        const <String, int>{};
    final betaLoop =
        await _betaActivationLoopStore?.exportAggregateCounts() ??
        const <String, int>{};
    final payload = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'localOnly': true,
      'description':
          'User-requested export of coarse interaction events stored only on '
          'this device. It does not include journal or audio content.',
      'categories': [
        {
          'id': 'paywall_attribution',
          'description':
              'Coarse paywall funnel stages, source categories, and times.',
          'events': paywall,
        },
        {
          'id': 'suggestion_attribution',
          'description':
              'Coarse suggestion interaction stages and times. Safe internal '
              'suggestion tokens may be included.',
          'events': suggestions,
        },
        {
          'id': 'archive_activation_funnel',
          'description': 'Archive activation event type counts only.',
          'counts': archiveActivation,
        },
        {
          'id': 'retention_metrics',
          'description': 'Retention and onboarding event counts only.',
          'counts': retention,
        },
        {
          'id': 'beta_activation_summary',
          'description': 'Beta activation summary counts only.',
          'counts': betaSummary,
        },
        {
          'id': 'beta_activation_loop',
          'description': 'Beta activation loop counts only.',
          'counts': betaLoop,
        },
      ],
    };
    return BehavioralLogExportArtifact(
      contents: const JsonEncoder.withIndent('  ').convert(payload),
      exportedAt: exportedAt,
      eventCount:
          paywall.length +
          suggestions.length +
          _sumCounts(archiveActivation) +
          _sumCounts(retention) +
          _sumCounts(betaSummary) +
          _sumCounts(betaLoop),
    );
  }

  /// Attempts every allowlisted removal even if an earlier store fails.
  Future<void> clear() async {
    Object? firstError;
    StackTrace? firstStack;
    final clears = <Future<void> Function()>[
      _paywallStore.clear,
      _suggestionStore.clear,
      if (_archiveActivationStore != null) _archiveActivationStore.clear,
      if (_retentionMetricsStore != null) _retentionMetricsStore.clear,
      if (_betaActivationSummaryStore != null)
        _betaActivationSummaryStore.clear,
      if (_betaActivationLoopStore != null) _betaActivationLoopStore.clear,
    ];
    for (final clear in clears) {
      try {
        await clear();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }

  static int _sumCounts(Map<String, int> counts) =>
      counts.values.fold(0, (total, count) => total + count);
}
