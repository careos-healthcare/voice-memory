import 'dart:async';

import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/pro_trail_gate.dart';
import 'package:archiveme_mobile/features/comparison_engine/infrastructure/comparison_preference_store.dart';
import 'package:archiveme_mobile/features/comparison_engine/infrastructure/journal_comparison_model_api_client.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/widgets/pattern_evidence_card.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/billing/paywall_gate.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tier 2 historical comparison — Pro-gated with full citation trail on capped free entries.
class ComparisonEngineScreen extends ConsumerStatefulWidget {
  const ComparisonEngineScreen({super.key});

  @override
  ConsumerState<ComparisonEngineScreen> createState() =>
      _ComparisonEngineScreenState();
}

class _ComparisonEngineScreenState extends ConsumerState<ComparisonEngineScreen> {
  PostSaveComparisonController? _controller;
  bool _loading = true;
  List<JournalEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    // `ensureInitialized` reaches `SubscriptionNotifier._initRevenueCat`, which
    // writes `state` before its first await, so awaiting it straight from
    // `initState` mutates a provider mid-build. Run it once the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    await ref.read(subscriptionNotifierProvider).ensureInitialized();
    final entries = await AppServices.instance.journal.loadAll();
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (!mounted) return;

    setState(() {
      _entries = realEntries;
      _loading = false;
    });

    if (ref.read(isProUserProvider)) {
      await _runComparison(realEntries);
    }
  }

  Future<void> _runComparison(List<JournalEntry> entries) async {
    if (entries.length < 2) return;

    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final current = sorted.last;
    final historical = sorted
        .sublist(0, sorted.length - 1)
        .map(
          (entry) => ArchiveMomentRecord(
            id: entry.id,
            savedWords: entry.transcript.trim(),
            createdAt: entry.createdAt,
          ),
        )
        .where((moment) => moment.savedWords.isNotEmpty)
        .toList(growable: false);

    if (historical.isEmpty) return;

    final isPro = ref.read(isProUserProvider);
    final controller = PostSaveComparisonController(
      apiClient: JournalComparisonModelApiClient(entries: entries),
      prefs: ComparisonPreferenceStore(AppServices.instance.prefs),
    );
    _controller = controller;
    controller.addListener(() {
      if (mounted) setState(() {});
    });

    await controller.processMomentComparison(
      currentMoment: ArchiveMomentRecord(
        id: current.id,
        savedWords: current.transcript.trim(),
        createdAt: current.createdAt,
      ),
      historicalMoments: historical,
      isProUser: isPro,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isProUserProvider, (previous, next) {
      if (next && _controller == null && !_loading && _entries.length >= 2) {
        unawaited(_runComparison(_entries));
      }
    });

    if (_loading) {
      return const PushedScreenShell(
        title: 'Historical comparison',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PaywallGate(
      featureName: 'Historical comparison',
      feature: ArchiveFeature.tier2HistoricalComparison,
      sourceRoute: '/comparison-engine',
      onDismiss: () => context.pop(),
      child: _buildComparisonBody(),
    );
  }

  Widget _buildComparisonBody() {
    final uiState = _controller?.uiState;
    final isPro = ref.watch(isProUserProvider);

    return PushedScreenShell(
      title: 'Historical comparison',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Evidence-linked then vs now across your saved moments.',
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
          if (!isPro) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Free shows ${ProTrailGate.freeHistoricalMomentLimit} prior moment with '
              'full citation quotes. Pro unlocks the complete thread.',
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (uiState is ComparisonLoading)
            const Center(child: CircularProgressIndicator())
          else if (uiState is ComparisonFailure)
            Text(uiState.errorMessage)
          else if (uiState is ComparisonSuccess)
            PatternEvidenceCard(
              viewState: uiState.viewState,
              onProUpgradeTapped: () => context.push('/subscription'),
            )
          else
            Text(
              _entries.length < 2
                  ? 'Save at least two moments to compare how your archive evolved.'
                  : 'Loading comparison…',
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
        ],
      ),
    );
  }
}