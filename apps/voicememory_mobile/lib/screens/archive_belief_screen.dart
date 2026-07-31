import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/weekly_archive_review.dart';
import '../features/archive_beliefs/archive_belief_providers.dart';
import '../features/archive_home/archive_intelligence_home.dart';
import '../features/archive_home/archive_intelligence_presentation.dart';
import '../features/first25/first25_user_metrics.dart';
import '../features/retention/retention_analytics.dart';
import '../router/primary_destination.dart';
import '../router/primary_navigation_controller.dart';
import '../router/route_catalog.dart';
import '../theme/app_colors.dart';
import '../widgets/accessibility/accessible_primary_surface.dart';

/// Archive Intelligence home: coordinates archive state and delegates rendering.
class ArchiveBeliefScreen extends StatelessWidget {
  const ArchiveBeliefScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _ArchiveBeliefView());
  }
}

class _ArchiveBeliefView extends ConsumerStatefulWidget {
  const _ArchiveBeliefView();

  @override
  ConsumerState<_ArchiveBeliefView> createState() => _ArchiveBeliefViewState();
}

class _ArchiveBeliefViewState extends ConsumerState<_ArchiveBeliefView> {
  @override
  void initState() {
    super.initState();
    primaryNavigationController.addListener(_handlePrimaryActivation);
    First25UserMetrics.trackArchiveOpened(surface: 'archive_intelligence_home');
  }

  @override
  void dispose() {
    primaryNavigationController.removeListener(_handlePrimaryActivation);
    super.dispose();
  }

  void _handlePrimaryActivation() {
    if (!mounted ||
        primaryNavigationController.activeDestination !=
            PrimaryDestination.archive) {
      return;
    }
    ref.read(archiveBootstrapProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveBootstrapProvider);
    return AccessiblePrimarySurface(
      label: 'Archive Intelligence screen',
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          title: const Text('Archive'),
          actions: [
            TextButton.icon(
              key: const Key('archive_open_memory_graph'),
              onPressed: () => context.push(RouteCatalog.graphHome),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Memory graph'),
            ),
          ],
        ),
        body: archive.when(
          loading: () => const _ArchiveLoadingState(),
          error: (error, _) => _ArchiveErrorState(
            onRetry: () =>
                ref.read(archiveBootstrapProvider.notifier).refresh(),
          ),
          data: (snapshot) {
            final presentation = ArchiveIntelligencePresentation.build(
              entries: snapshot.entries,
              beliefs: snapshot.beliefs,
            );
            return ArchiveIntelligenceHome(
              presentation: presentation,
              onRefresh: () =>
                  ref.read(archiveBootstrapProvider.notifier).refresh(),
              onOpenMoment: (entryId) => _openMoment(context, entryId),
              onAction: (action) => _handleAction(context, action),
            );
          },
        ),
      ),
    );
  }

  void _openMoment(BuildContext context, String entryId) {
    RetentionAnalytics.evidenceRecordOpened(
      surface: 'archive_intelligence_home',
    );
    context.push('/entry/$entryId');
  }

  void _handleAction(BuildContext context, ArchiveIntelligenceAction action) {
    switch (action) {
      case ArchiveIntelligenceAction.recordMoment:
        context.go('/record');
      case ArchiveIntelligenceAction.viewEvidence:
        context.push(BeliefEvidenceNavigation.route);
      case ArchiveIntelligenceAction.viewReview:
        context.push(WeeklyArchiveReviewNavigation.route);
      case ArchiveIntelligenceAction.none:
        break;
    }
  }
}

class _ArchiveLoadingState extends StatelessWidget {
  const _ArchiveLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('archive_intelligence_loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _ArchiveErrorState extends StatelessWidget {
  const _ArchiveErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('archive_intelligence_error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Archive Intelligence could not load.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your saved moments are still on this device. Try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('archive_intelligence_retry'),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
