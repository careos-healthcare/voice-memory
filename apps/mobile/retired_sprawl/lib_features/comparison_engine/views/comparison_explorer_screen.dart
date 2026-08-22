import 'dart:async';

import 'package:archiveme_mobile/billing/tier2_paywall_gate.dart';
import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/comparison_explorer_query.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/pro_trail_gate.dart';
import 'package:archiveme_mobile/features/comparison_engine/infrastructure/comparison_preference_store.dart';
import 'package:archiveme_mobile/features/comparison_engine/infrastructure/journal_comparison_model_api_client.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/comparison_explorer_copy.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/comparison_explorer_lens_support.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/widgets/pattern_evidence_card.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/widgets/post_save_comparison_section.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full-screen temporal comparison explorer — independent of post-save flow.
class ComparisonExplorerScreen extends ConsumerStatefulWidget {
  const ComparisonExplorerScreen({super.key, this.initialWindow});

  /// Pre-selects a temporal window when opened from a deep link.
  final ComparisonTemporalWindow? initialWindow;

  @override
  ConsumerState<ComparisonExplorerScreen> createState() =>
      _ComparisonExplorerScreenState();
}

class _ComparisonExplorerScreenState
    extends ConsumerState<ComparisonExplorerScreen> {
  PostSaveComparisonController? _controller;
  bool _loadingEntries = true;
  List<JournalEntry> _entries = const [];
  ComparisonTemporalWindow _window = ComparisonTemporalWindow.recent;
  ComparisonExplorerSnapshot? _snapshot;
  bool _dismissedDeepWindowPaywall = false;
  LifeStageLens? _activeLens;

  @override
  void initState() {
    super.initState();
    _activeLens = AppServices.instance.userSettings.current.activeLens;
    _window = widget.initialWindow ??
        ComparisonExplorerLensSupport.defaultWindowFor(_activeLens);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(subscriptionNotifierProvider).ensureInitialized();
    final entries = await AppServices.instance.journal.loadAll();
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (!mounted) return;

    setState(() {
      _entries = realEntries;
      _loadingEntries = false;
      _snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: realEntries,
        window: _window,
      );
    });

    await _runComparisonIfReady();
  }

  Future<void> _reloadEntries() async {
    setState(() => _loadingEntries = true);
    final entries = await AppServices.instance.journal.loadAll();
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (!mounted) return;

    setState(() {
      _entries = realEntries;
      _loadingEntries = false;
      _snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: realEntries,
        window: _window,
      );
    });

    await _runComparisonIfReady();
  }

  Future<void> _onWindowSelected(ComparisonTemporalWindow window) async {
    final isPro = ref.read(isProUserProvider);
    if (window.requiresPro && !isPro) {
      setState(() {
        _window = window;
        _dismissedDeepWindowPaywall = false;
        _snapshot = ComparisonExplorerQuery.fromJournalEntries(
          entries: _entries,
          window: window,
        );
        _controller?.dispose();
        _controller = null;
      });
      return;
    }

    setState(() {
      _window = window;
      _dismissedDeepWindowPaywall = false;
      _snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: _entries,
        window: window,
      );
    });
    await _runComparisonIfReady();
  }

  Future<void> _continueOnFreeWindow() async {
    setState(() {
      _window = ComparisonTemporalWindow.recent;
      _dismissedDeepWindowPaywall = true;
      _snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: _entries,
        window: _window,
      );
    });
    await _runComparisonIfReady();
  }

  Future<void> _runComparisonIfReady() async {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.hasEnoughForComparison) {
      _controller?.dispose();
      _controller = null;
      if (mounted) setState(() {});
      return;
    }

    final current = snapshot.current!;
    final historical = snapshot.historical;
    final isPro = ref.read(isProUserProvider);

    _controller?.dispose();
    final controller = PostSaveComparisonController(
      apiClient: JournalComparisonModelApiClient(entries: _entries),
      prefs: ComparisonPreferenceStore(AppServices.instance.prefs),
    );
    _controller = controller;
    controller.addListener(() {
      if (mounted) setState(() {});
    });

    await controller.processMomentComparison(
      currentMoment: current,
      historicalMoments: historical,
      isProUser: isPro,
      systemPromptAddendum:
          ComparisonExplorerLensSupport.systemPromptAddendumFor(_activeLens),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _showDeepWindowPaywall {
    final isPro = ref.watch(isProUserProvider);
    return _window.requiresPro && !isPro && !_dismissedDeepWindowPaywall;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isProUserProvider, (previous, next) {
      if (next && !_loadingEntries) {
        unawaited(_runComparisonIfReady());
      }
    });

    if (_loadingEntries) {
      return const PushedScreenShell(
        title: ComparisonExplorerCopy.screenTitle,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = _snapshot;
    final isPro = ref.watch(isProUserProvider);
    final lensHeadline =
        ComparisonExplorerLensSupport.headlineFor(_activeLens);
    final intervalNudge =
        ComparisonExplorerLensSupport.intervalNudgeFor(_activeLens);

    return PushedScreenShell(
      title: ComparisonExplorerCopy.screenTitle,
      body: RefreshIndicator(
        onRefresh: _reloadEntries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              lensHeadline ??
                  snapshot?.window.headline ??
                  _window.headline,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              intervalNudge == null
                  ? 'Evidence-linked then vs now across your saved moments.'
                  : 'Switch between 2-week and 1-month views to see baseline movement.',
              style: ArchiveMobileTypography.responsiveBody(context),
            ),
            if (intervalNudge != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _LensIntervalPromptCard(
                nudge: intervalNudge,
                onSelectFortnight: () =>
                    unawaited(_onWindowSelected(ComparisonTemporalWindow.fortnight)),
                onSelectMonth: () =>
                    unawaited(_onWindowSelected(ComparisonTemporalWindow.recent)),
                selectedWindow: _window,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _ProTrailGateWrapper(isPro: isPro),
            if (_showDeepWindowPaywall) ...[
              Tier2PaywallIntercept(
                feature: Tier2PaywallGate.featureForComparison(),
                momentCount: snapshot?.momentCount ?? 0,
                onContinueFree: _continueOnFreeWindow,
              ),
            ] else ...[
              _WindowPicker(
                selected: _window,
                isPro: isPro,
                activeLens: _activeLens,
                onSelected: _onWindowSelected,
              ),
              if (snapshot != null && snapshot.momentCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ComparisonExplorerCopy.momentCountLabel(snapshot.momentCount),
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _ComparisonResultBody(
                snapshot: snapshot,
                controller: _controller,
                onProUpgradeTapped: () => context.push('/subscription'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Surfaces [ProTrailGate] free-tier limits at the screen wrapper level.
class _ProTrailGateWrapper extends StatelessWidget {
  const _ProTrailGateWrapper({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    if (isPro) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ProTrailGate.conversionHeadline,
                style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Free shows ${ProTrailGate.freeHistoricalMomentLimit} prior moment with '
                'full citation quotes. Pro unlocks the complete thread.',
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LensIntervalPromptCard extends StatelessWidget {
  const _LensIntervalPromptCard({
    required this.nudge,
    required this.onSelectFortnight,
    required this.onSelectMonth,
    required this.selectedWindow,
  });

  final String nudge;
  final VoidCallback onSelectFortnight;
  final VoidCallback onSelectMonth;
  final ComparisonTemporalWindow selectedWindow;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compare intervals',
              style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              nudge,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ActionChip(
                  label: const Text('Last 2 weeks'),
                  onPressed: onSelectFortnight,
                  backgroundColor: selectedWindow == ComparisonTemporalWindow.fortnight
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                ActionChip(
                  label: const Text('Last month'),
                  onPressed: onSelectMonth,
                  backgroundColor: selectedWindow == ComparisonTemporalWindow.recent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowPicker extends StatelessWidget {
  const _WindowPicker({
    required this.selected,
    required this.isPro,
    required this.activeLens,
    required this.onSelected,
  });

  final ComparisonTemporalWindow selected;
  final bool isPro;
  final LifeStageLens? activeLens;
  final ValueChanged<ComparisonTemporalWindow> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ComparisonExplorerCopy.windowSectionTitle,
          style: ArchiveMobileTypography.responsiveBody(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final window in ComparisonTemporalWindow.values)
              ChoiceChip(
                label: Text(
                  ComparisonExplorerLensSupport.isRecommendedWindow(
                        activeLens,
                        window,
                      )
                      ? '${window.label} • suggested'
                      : window.label,
                ),
                selected: selected == window,
                onSelected: (_) => onSelected(window),
                avatar: window.requiresPro && !isPro
                    ? Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonResultBody extends StatelessWidget {
  const _ComparisonResultBody({
    required this.snapshot,
    required this.controller,
    required this.onProUpgradeTapped,
  });

  final ComparisonExplorerSnapshot? snapshot;
  final PostSaveComparisonController? controller;
  final VoidCallback onProUpgradeTapped;

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    if (snap == null || snap.momentCount == 0) {
      return const _InsufficientDataCard(
        title: ComparisonExplorerCopy.insufficientMomentsTitle,
        body: ComparisonExplorerCopy.emptyArchiveBody,
      );
    }

    if (!snap.hasEnoughForComparison) {
      return _InsufficientDataCard(
        title: ComparisonExplorerCopy.insufficientMomentsTitle,
        body: ComparisonExplorerCopy.insufficientMomentsBody(snap.window.label),
      );
    }

    final uiState = controller?.uiState;
    if (uiState is ComparisonLoading || uiState == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ComparisonExplorerCopy.loadingComparison,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
        ),
      );
    }

    if (uiState is ComparisonFailure) {
      return _InsufficientDataCard(
        title: 'Comparison unavailable',
        body: uiState.errorMessage,
      );
    }

    if (uiState is ComparisonSuccess) {
      final viewState = uiState.viewState;
      if (viewState.state == PatternState.notEnoughEvidence ||
          viewState.pastQuote.trim().isEmpty ||
          viewState.currentQuote.trim().isEmpty) {
        return _InsufficientDataCard(
          title: ComparisonExplorerCopy.insufficientMomentsTitle,
          body:
              'ArchiveMe needs more aligned moments in ${snap.window.label} to surface a pattern.',
        );
      }

      if (controller != null) {
        return PostSaveComparisonSection(
          controller: controller!,
          onProUpgradeTapped: onProUpgradeTapped,
        );
      }

      return PatternEvidenceCard(
        viewState: viewState,
        onProUpgradeTapped: onProUpgradeTapped,
      );
    }

    return const SizedBox.shrink();
  }
}

class _InsufficientDataCard extends StatelessWidget {
  const _InsufficientDataCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: ArchiveMobileTypography.responsiveHelper(context)),
          ],
        ),
      ),
    );
  }
}