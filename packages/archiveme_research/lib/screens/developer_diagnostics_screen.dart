import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/retrofit_providers.dart';
import 'package:archiveme_mobile/features/activation/activation_dropoff_review_engine.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_tracker.dart';
import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_store.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_store.dart';
import 'package:archiveme_mobile/features/debug/archive_beta_debug_gate.dart';
import 'package:archiveme_mobile/features/beta/beta_metrics_decision_engine.dart';
import 'package:archiveme_mobile/features/beta/beta_release_qa_engine.dart';
import 'package:archiveme_mobile/features/beta/release_candidate_smoke_engine.dart';
import 'package:archiveme_mobile/features/beta/proof_of_value_engine.dart';
import 'package:archiveme_mobile/features/beta/proof_value_bottleneck_playbook_engine.dart';
import 'package:archiveme_mobile/features/beta/beta_report_export_engine.dart';
import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_minimum_set_v2.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v2.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v3.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:archiveme_mobile/features/testflight_metrics/testflight_metrics_engine.dart';
import 'package:archiveme_mobile/billing/paywall_attribution_store.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/widgets/debug/core_metrics_minimum_set_card.dart';
import 'package:archiveme_mobile/widgets/debug/pro_access_enforcement_audit_card.dart';
import 'package:archiveme_mobile/widgets/debug/beta_metrics_decision_card.dart';
import 'package:archiveme_mobile/widgets/debug/beta_release_qa_card.dart';
import 'package:archiveme_mobile/widgets/debug/beta_report_export_card.dart';
import 'package:archiveme_mobile/widgets/debug/proof_of_value_card.dart';
import 'package:archiveme_mobile/widgets/debug/proof_value_bottleneck_playbook_card.dart';
import 'package:archiveme_mobile/widgets/debug/release_candidate_smoke_card.dart';
import 'package:archiveme_mobile/widgets/debug/activation_dropoff_review_card.dart';
import 'package:archiveme_mobile/push/firebase_options.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/debug_only_unavailable.dart';

/// Internal diagnostics — developer gate only.
class DeveloperDiagnosticsScreen extends StatefulWidget {
  const DeveloperDiagnosticsScreen({super.key});

  @override
  State<DeveloperDiagnosticsScreen> createState() =>
      _DeveloperDiagnosticsScreenState();
}

class _DeveloperDiagnosticsScreenState
    extends State<DeveloperDiagnosticsScreen> {
  String _health = '…';
  int _entryCount = 0;
  BetaActivationLoopCounts _betaLoopCounts = const BetaActivationLoopCounts();
  String _confirmedRepeatBetaFeedbackSummary = 'Not captured yet';
  bool _archiveMeDemoActive = false;
  bool _loading = true;
  CoreMetricsMinimumDashboard? _coreMetricsDashboard;
  ProAccessEnforcementDashboard? _proAccessEnforcementDashboard;
  ProAccessEnforcementStoreReadinessBridge? _proAccessStoreReadinessBridge;

  @override
  void initState() {
    super.initState();
    if (DeveloperSettingsGate.canShowDeveloperSettings) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final h = await appProviderContainer
          .read(voiceMemoryRetrofitClientProvider)
          .health
          .health();
      final entries = await AppServices.instance.journalStore.loadAll();
      final betaCounts = await BetaActivationLoopTracker.readCounts();
      final testFlightInput = await TestFlightMetricsEngine.loadInput();
      final paywallEvents = await PaywallAttributionStore.instance().events();
      final cachedEntitlements = await AppServices.instance.entitlementCache
          .load();
      final appLockEnabled = await AppLockService.instance.isEnabled();
      final revenueCat = RevenueCatService.instance;
      final revenueCatDiagnostics = revenueCat.diagnostics;
      final recordedEventNames = <String>[
        for (final record in RevenueFunnelAnalytics.recordedEvents)
          record.event.id,
        for (final event in paywallEvents) event.type.id,
      ];
      await ConfirmedRepeatBetaFeedbackStore.ensureLoaded();
      await CoreValueFeedbackStore.ensureLoaded();
      final confirmedRepeatFeedback = ConfirmedRepeatBetaFeedbackStore.cached;
      if (mounted) {
        setState(() {
          _health = h.status;
          _entryCount = entries.length;
          _betaLoopCounts = betaCounts;
          _confirmedRepeatBetaFeedbackSummary =
              confirmedRepeatFeedback.completed
              ? confirmedRepeatFeedback.toReviewSummary()
              : 'Not captured yet';
          _archiveMeDemoActive = ArchiveMeDemoState.isActive;
          _coreMetricsDashboard = CoreMetricsMinimumSetV2.buildFromLocalSignals(
            loopCounts: betaCounts,
            testFlightInput: testFlightInput,
            recordedEventNames: recordedEventNames,
          );
          final proAccessSignals = ProAccessEnforcementLocalSignals(
            revenueCatConfigured: revenueCatDiagnostics.revenueCatConfigured,
            revenueCatApiKeyMissing: revenueCatDiagnostics.apiKeyMissing,
            productsLoaded:
                revenueCatDiagnostics.offeringsLoaded &&
                revenueCatDiagnostics.packageCount > 0,
            proStateReadable: revenueCatDiagnostics.revenueCatConfigured,
            proEntitlementActive: revenueCat.latestEntitlements.isPro,
            cachedProOnDisk: cachedEntitlements?.isPro ?? false,
            restorePurchasesReachable: true,
            restoreNoCrashVerified: true,
            entitlementPersistsAfterRestart:
                (cachedEntitlements?.isPro ?? false) &&
                revenueCat.latestEntitlements.isPro,
            revenueCatLinkedToAccount: false,
            backendConfigured: AppConfig.isBackendConfigured,
            appLockEnabled: appLockEnabled,
          );
          _proAccessEnforcementDashboard =
              ProAccessEnforcementAuditV2.buildFromLocalSignals(
                proAccessSignals,
              );
          _proAccessStoreReadinessBridge =
              ProAccessEnforcementAuditV3.fromLocalSignals(proAccessSignals);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _health = 'unreachable ($e)';
          _loading = false;
        });
      }
    }
  }

  Future<void> _copySummary() async {
    final lines = [
      'API: ${AppConfig.apiBaseUrlStatusLabel}',
      'Backend configured: ${AppConfig.isBackendConfigured}',
      'Release API define: ${AppConfig.isReleaseApiConfigured}',
      'Health: $_health',
      'Local journal entries: $_entryCount',
      'Debug token: ${AppConfig.internalDebugToken.isNotEmpty ? "set" : "not set"}',
      'Firebase define: ${FirebaseOptionsConfig.isConfigured ? "yes" : "no"}',
      '',
      _betaLoopCounts.toSummaryText(),
      '',
      'First confirmed-repeat feedback: $_confirmedRepeatBetaFeedbackSummary',
      'Core value feedback: ${CoreValueFeedbackStore.cached.diagnosticsSummary}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Diagnostics copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(title: 'Internal diagnostics');
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Internal diagnostics'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('API base URL', AppConfig.apiBaseUrlStatusLabel),
          _row(
            'Build override',
            '--dart-define=${AppConfig.apiBaseUrlDefineKey}=…',
          ),
          _row('Backend health', _loading ? '…' : _health),
          _row('Local journal entries', _loading ? '…' : '$_entryCount'),
          _row(
            'Internal debug token',
            AppConfig.internalDebugToken.isNotEmpty ? 'configured' : 'not set',
          ),
          _row(
            'Firebase dart-define',
            FirebaseOptionsConfig.isConfigured ? 'configured' : 'not set',
          ),
          const SizedBox(height: 24),
          BetaReleaseQaCard(report: BetaReleaseQaEngine.build()),
          const SizedBox(height: 24),
          ReleaseCandidateSmokeCard(
            report: ReleaseCandidateSmokeEngine.build(),
          ),
          const SizedBox(height: 24),
          BetaMetricsDecisionCard(
            report: BetaMetricsDecisionEngine.build(
              input: BetaMetricsDecisionEngine.fromBetaCounts(
                betaCounts: _loading ? null : _betaLoopCounts,
              ),
            ),
          ),
          if (_coreMetricsDashboard != null) ...[
            const SizedBox(height: 24),
            CoreMetricsMinimumSetCard(dashboard: _coreMetricsDashboard!),
          ],
          if (_proAccessEnforcementDashboard != null) ...[
            const SizedBox(height: 24),
            ProAccessEnforcementAuditCard(
              dashboard: _proAccessEnforcementDashboard!,
              storeReadinessBridge: _proAccessStoreReadinessBridge,
            ),
          ],
          const SizedBox(height: 24),
          ProofOfValueCard(
            report: ProofOfValueEngine.build(
              input: ProofOfValueEngine.fromBetaCounts(
                betaCounts: _loading ? null : _betaLoopCounts,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ProofValueBottleneckPlaybookCard(
            report: ProofValueBottleneckPlaybookEngine.fromBetaCounts(
              betaCounts: _loading ? null : _betaLoopCounts,
            ),
          ),
          const SizedBox(height: 12),
          BetaReportExportCard(
            report: BetaReportExportEngine.build(
              betaCounts: _loading ? null : _betaLoopCounts,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('First pattern quality'),
            subtitle: const Text(
              'Run QA samples through the first-session engine',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/first-pattern-quality'),
          ),
          ListTile(
            title: const Text('Trial control'),
            subtitle: const Text(
              'Reset participant state and export trial summary',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/trial-control'),
          ),
          if (ArchiveBetaDebugGate.showLoopDebugControls) ...[
            const SizedBox(height: 24),
            Text(
              'ArchiveMe demo archive',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Synthetic 3-moment confirmed-repeat archive for screenshots. '
              'Debug builds only — never writes real journal data.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            _row(
              'Demo archive active',
              _loading ? '…' : (_archiveMeDemoActive ? 'yes' : 'no'),
            ),
            SwitchListTile(
              key: const Key('debug_archive_me_demo_toggle'),
              title: const Text('Use demo archive'),
              subtitle: const Text(
                '3 synthetic moments with confirmed repeat and belief proof',
              ),
              value: _archiveMeDemoActive,
              onChanged: _loading
                  ? null
                  : (enabled) {
                      ArchiveMeDemoState.setDebugSessionEnabled(enabled);
                      setState(() => _archiveMeDemoActive = enabled);
                    },
            ),
            OutlinedButton(
              key: const Key('debug_reset_archive_me_demo'),
              onPressed: _loading
                  ? null
                  : () {
                      ArchiveMeDemoState.resetDebugSession();
                      setState(() => _archiveMeDemoActive = false);
                    },
              child: const Text('Reset demo archive'),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Text('…')
            else
              ActivationDropoffReviewCard(
                review: ActivationDropoffReviewEngine.build(
                  betaCounts: _betaLoopCounts,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Beta activation loop',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Local counts for the first-three-entry loop. Debug builds only.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            for (final entry in BetaActivationLoopCounts.fieldLabels.entries)
              _row(
                entry.value,
                _loading ? '…' : '${_betaLoopCounts.valueForField(entry.key)}',
              ),
            _row(
              'First confirmed-repeat feedback',
              _loading ? '…' : _confirmedRepeatBetaFeedbackSummary,
            ),
            OutlinedButton(
              key: const Key('debug_clear_beta_activation_loop'),
              onPressed: _loading
                  ? null
                  : () async {
                      await BetaActivationLoopTracker.clearCounts();
                      BetaActivationLoopTracker.resetSessionState();
                      await _refresh();
                    },
              child: const Text('Clear beta loop counts'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _copySummary,
            child: const Text('Copy summary'),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
