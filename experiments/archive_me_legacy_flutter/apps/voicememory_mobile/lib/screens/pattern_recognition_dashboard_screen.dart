import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/insights/archive_insight.dart';
import '../features/journal_playback/rich_memory_playback.dart';
import '../features/monetization/domain/services/monetization_analytics.dart';
import '../features/pattern_recognition/pattern_recognition_dashboard_provider.dart';
import '../features/explainable_conclusion/explainable_conclusion_validator.dart';
import '../features/explainable_conclusion/explainable_conclusion_widgets.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/value_moment_paywall.dart';

class PatternRecognitionDashboard extends ConsumerWidget {
  const PatternRecognitionDashboard({
    super.key,
    this.analytics = const ProductMonetizationAnalyticsEngine(),
  });

  final AnalyticsEngine analytics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(patternRecognitionDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        title: const Text('Pattern recognition'),
        actions: [
          IconButton(
            tooltip: 'Refresh insights',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => unawaited(
              ref.read(patternRecognitionDashboardProvider.notifier).refresh(),
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _DashboardError(
            onRetry: () => unawaited(
              ref.read(patternRecognitionDashboardProvider.notifier).refresh(),
            ),
          ),
          data: (data) => _DashboardBody(data: data, analytics: analytics),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data, required this.analytics});

  final PatternRecognitionDashboardState data;
  final AnalyticsEngine analytics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (data.backendRestricted) ...[
            const _BackendRestrictionBanner(),
            const SizedBox(height: AppSpacing.lg),
          ],
          const _EmptyDashboard(),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(patternRecognitionDashboardProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (data.backendRestricted) ...[
            const _BackendRestrictionBanner(),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'Signals grounded in your analyzed journal history.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          if (data.loadedFromLocalFallback && !data.backendRestricted) ...[
            const SizedBox(height: AppSpacing.sm),
            const _OfflineNotice(),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Recurring topics', icon: Icons.hub_outlined),
          const SizedBox(height: AppSpacing.sm),
          _TopicsCard(topics: data.recurringTopics),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Mood trends', icon: Icons.insights_outlined),
          const SizedBox(height: AppSpacing.sm),
          _MoodTrendsCard(trends: data.moodTrends),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(
            title: 'AI-driven insights',
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!data.isPro)
            _BlurredInsightsTeaser(
              insights: data.insights.allInsights.take(2).toList(),
              analytics: analytics,
            )
          else if (data.insights.allInsights.isEmpty)
            const _InsightEmptyCard()
          else
            ...data.insights.allInsights
                .take(4)
                .map(
                  (insight) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _InsightCard(insight: insight),
                  ),
                ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Past memories', icon: Icons.history),
          const SizedBox(height: AppSpacing.sm),
          ...data.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MemoryCard(
                entry: entry,
                isPro: data.isPro,
                analytics: analytics,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendRestrictionBanner extends StatelessWidget {
  const _BackendRestrictionBanner();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pattern_dashboard_backend_restricted'),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cloud features are limited',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cloud sync, transcription, and reflections need a configured backend. '
                'Local vault recording remains available.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BlurredInsightsTeaser extends StatelessWidget {
  const _BlurredInsightsTeaser({
    required this.insights,
    required this.analytics,
  });

  final List<ArchiveInsight> insights;
  final AnalyticsEngine analytics;

  @override
  Widget build(BuildContext context) {
    final preview = insights.isEmpty
        ? const [
            (
              'A pattern is becoming clearer',
              'Several recent memories share a common signal.',
            ),
            (
              'Your mood shifted around one theme',
              'See what changed and the evidence behind it.',
            ),
          ]
        : insights.map((insight) => (insight.title, insight.summary)).toList();

    return Column(
      key: const Key('pattern_recognition_insights_teaser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Column(
              children: [
                for (final item in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: VoiceMemoryCards.standard(
                        background: AppColors.backgroundSecondary,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(item.$2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ValueMomentPaywall(
          reason: ValueMomentPaywallReason.premiumInsights,
          onUpgradeTapped: _trackUpgradeTap,
        ),
      ],
    );
  }

  void _trackUpgradeTap() {
    analytics.logEvent(
      'insight_upgrade_cta_clicked',
      parameters: const {'trigger_source': 'insight_tease'},
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.accentPrimary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ],
  );
}

class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.topics});

  final List<RecurringTopic> topics;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pattern_recognition_topics'),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: VoiceMemoryCards.standard(),
    child: topics.isEmpty
        ? const Text('More analyzed entries will reveal recurring topics.')
        : Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final topic in topics)
                Chip(label: Text('${topic.label} · ${topic.count}')),
            ],
          ),
  );
}

class _MoodTrendsCard extends StatelessWidget {
  const _MoodTrendsCard({required this.trends});

  final List<MoodTrend> trends;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pattern_recognition_moods'),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: VoiceMemoryCards.standard(),
    child: trends.isEmpty
        ? const Text('Mood trends will appear after reflection analysis.')
        : Column(
            children: [
              for (final trend in trends)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(trend.mood)),
                      Text('${trend.count} entries'),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 72,
                        child: LinearProgressIndicator(
                          value: (trend.averageIntensity / 5).clamp(0, 1),
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final ArchiveInsight insight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: VoiceMemoryCards.standard(
      background: AppColors.backgroundSecondary,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(insight.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(insight.summary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${insight.evidenceCount} supporting memories · '
          '${insight.confidence}% confidence',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.entry,
    required this.isPro,
    required this.analytics,
  });

  final JournalEntry entry;
  final bool isPro;
  final AnalyticsEngine analytics;

  @override
  Widget build(BuildContext context) {
    final conclusion = entry.reflection.explainableConclusion;
    final gated = conclusion == null
        ? null
        : ExplainableConclusionRenderGate.visible(
            conclusion,
            canonicalTranscripts: {entry.id: entry.transcript},
          );
    return Card(
      key: Key('pattern_memory_${entry.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              entry.localAudioReference == null
                  ? Icons.notes
                  : Icons.play_circle_outline,
              color: AppColors.accentPrimary,
            ),
            title: Text(
              entry.transcript.trim().isEmpty
                  ? 'Transcript unavailable'
                  : entry.transcript,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              MaterialLocalizations.of(
                context,
              ).formatShortDate(entry.createdAt),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              useSafeArea: true,
              builder: (context) => SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
                  ),
                  child: RichMemoryPlayback(
                    entry: entry,
                    hasProAccess: isPro,
                    analytics: analytics,
                  ),
                ),
              ),
            ),
          ),
          if (gated != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: ExplainableConclusionCard(
                conclusion: gated,
                onShowHistory: () async {
                  if (!AppServices.isInitialized) return;
                  final history = await AppServices
                      .instance
                      .explainabilityHistoryStore
                      .byConclusionId(gated.value.id);
                  if (!context.mounted) return;
                  await ExplainableHistorySheet.show(
                    context,
                    entries: history,
                    canonicalTranscripts: {entry.id: entry.transcript},
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text('Showing insights from your on-device archive.'),
  );
}

class _InsightEmptyCard extends StatelessWidget {
  const _InsightEmptyCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: VoiceMemoryCards.standard(),
    child: const Text(
      'Keep recording real moments. Insights appear only when there is enough supporting evidence.',
    ),
  );
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'Your pattern dashboard will appear after your first analyzed memory.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Insights could not be loaded.'),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
