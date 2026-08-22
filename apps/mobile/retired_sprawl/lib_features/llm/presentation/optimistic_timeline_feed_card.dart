import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/features/llm/presentation/llm_stream_panel.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

/// Timeline card that optimistically shows raw capture text, then swaps to
/// extracted nodes + summary when background LLM analysis completes.
class OptimisticTimelineFeedCard extends StatelessWidget {
  const OptimisticTimelineFeedCard({
    required this.state,
    super.key,
    this.tokenStream,
    this.onTap,
  });

  final LlmFeedCardState state;
  final Stream<LlmStreamToken>? tokenStream;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat.yMMMMd()
        .add_jm()
        .format(state.createdAt.toLocal());

    return Semantics(
      button: onTap != null,
      label: 'Captured reflection from $date',
      child: Card(
        key: Key('optimistic_timeline_feed_${state.captureId}'),
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Voice',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _RawCaptureSection(state: state),
                const SizedBox(height: AppSpacing.sm),
                _AnalysisSection(state: state, tokenStream: tokenStream),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RawCaptureSection extends StatelessWidget {
  const _RawCaptureSection({required this.state});

  final LlmFeedCardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = state.rawTranscript.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you recorded',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          raw.isEmpty ? 'Voice recording captured locally.' : raw,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({
    required this.state,
    this.tokenStream,
  });

  final LlmFeedCardState state;
  final Stream<LlmStreamToken>? tokenStream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analysis',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (state.status) {
            LlmAnalysisStatus.pendingAnalysis =>
              _PendingAnalysisBody(key: ValueKey(state.captureId)),
            LlmAnalysisStatus.processing ||
            LlmAnalysisStatus.streaming =>
              _StreamingAnalysisBody(
                key: ValueKey('${state.captureId}_stream'),
                state: state,
                tokenStream: tokenStream,
              ),
            LlmAnalysisStatus.completed =>
              _CompletedAnalysisBody(
                key: ValueKey('${state.captureId}_done'),
                state: state,
              ),
            LlmAnalysisStatus.error =>
              _ErrorAnalysisBody(
                key: ValueKey('${state.captureId}_error'),
                message: state.errorMessage,
              ),
          },
        ),
      ],
    );
  }
}

class _PendingAnalysisBody extends StatelessWidget {
  const _PendingAnalysisBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      key: const Key('llm_feed_shimmer'),
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.backgroundSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 220,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 28,
            width: 140,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingAnalysisBody extends StatelessWidget {
  const _StreamingAnalysisBody({
    required this.state,
    this.tokenStream,
    super.key,
  });

  final LlmFeedCardState state;
  final Stream<LlmStreamToken>? tokenStream;

  @override
  Widget build(BuildContext context) {
    final stream = tokenStream;
    if (stream != null) {
      return LlmStreamPanel(tokenStream: stream);
    }

    return Text(
      state.streamingText.trim().isEmpty
          ? 'Analyzing reflection…'
          : state.streamingText,
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _CompletedAnalysisBody extends StatelessWidget {
  const _CompletedAnalysisBody({required this.state, super.key});

  final LlmFeedCardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.summary.trim().isNotEmpty)
          Text(
            state.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (state.nodes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final node in state.nodes)
                Chip(
                  key: Key('llm_feed_node_${node.id}'),
                  label: Text(node.label),
                  backgroundColor: _chipColor(node.kind),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Color _chipColor(String kind) {
    return switch (kind) {
      'journal_entry' => AppColors.accentLight,
      'tension' => AppColors.destructiveLight,
      'next_action' => AppColors.accentLight,
      'theme' => AppColors.surfaceAlt,
      _ => AppColors.backgroundSecondary,
    };
  }
}

class _ErrorAnalysisBody extends StatelessWidget {
  const _ErrorAnalysisBody({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message ?? 'Analysis failed. Your recording is still saved locally.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.error,
      ),
    );
  }
}
