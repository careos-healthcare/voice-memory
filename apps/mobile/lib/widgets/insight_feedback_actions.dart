import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_copy.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_store.dart';
import 'package:archiveme_mobile/features/then_now/then_now_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Compact local insight feedback actions — no private text, no network.
class InsightFeedbackActions extends StatefulWidget {
  const InsightFeedbackActions({
    required this.insightId, required this.insightType, required this.sourceRoute, super.key,
    this.show = true,
    this.onSaved,
    this.watchlistRoute = ThenNowCopy.archiveHomeRoute,
  });

  const InsightFeedbackActions.test({
    required this.insightId, required this.insightType, required this.sourceRoute, super.key,
    this.show = true,
    this.onSaved,
    this.watchlistRoute = ThenNowCopy.archiveHomeRoute,
  });

  final String insightId;
  final InsightFeedbackType insightType;
  final String sourceRoute;
  final bool show;
  final VoidCallback? onSaved;
  final String watchlistRoute;

  @override
  State<InsightFeedbackActions> createState() => _InsightFeedbackActionsState();
}

class _InsightFeedbackActionsState extends State<InsightFeedbackActions> {
  InsightFeedbackRecord? _latest;
  bool _justSaved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    await InsightFeedbackStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _latest = InsightFeedbackStore.latestFor(widget.insightId);
      _loading = false;
    });
  }

  Future<void> _save(InsightFeedbackChoice choice) async {
    await InsightFeedbackStore.ensureLoaded();
    final record = InsightFeedbackRecord(
      insightId: widget.insightId,
      insightType: widget.insightType,
      choice: choice,
      createdAt: DateTime.now(),
      sourceRoute: widget.sourceRoute,
    );
    await InsightFeedbackStore.instance().saveRecord(record);
    widget.onSaved?.call();
    if (!mounted) return;
    setState(() {
      _latest = record;
      _justSaved = true;
    });
    if (choice == InsightFeedbackChoice.saveAsWatchTheme && mounted) {
      await context.push(widget.watchlistRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show || _loading) {
      return const SizedBox.shrink(key: Key('insight_feedback_actions_hidden'));
    }

    final explainStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );
    final chipStyle = ArchiveMobileTypography.cardLabel(
      context,
      color: AppColors.accentPrimary,
    );

    return Column(
      key: const Key('insight_feedback_actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppSpacing.lg),
        Text(
          InsightFeedbackCopy.prompt,
          key: const Key('insight_feedback_prompt'),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _actionChip(
              key: const Key('insight_feedback_fits'),
              label: InsightFeedbackCopy.fits,
              onPressed: () => _save(InsightFeedbackChoice.fits),
              style: chipStyle,
            ),
            _actionChip(
              key: const Key('insight_feedback_not_quite'),
              label: InsightFeedbackCopy.notQuite,
              onPressed: () => _save(InsightFeedbackChoice.notQuite),
              style: chipStyle,
            ),
            _actionChip(
              key: const Key('insight_feedback_too_early'),
              label: InsightFeedbackCopy.tooEarly,
              onPressed: () => _save(InsightFeedbackChoice.tooEarly),
              style: chipStyle,
            ),
            _actionChip(
              key: const Key('insight_feedback_watch_theme'),
              label: InsightFeedbackCopy.saveAsWatchTheme,
              onPressed: () => _save(InsightFeedbackChoice.saveAsWatchTheme),
              style: chipStyle,
            ),
          ],
        ),
        if (_latest != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            InsightFeedbackCopy.latestChoiceLabel(_latest!.choice),
            key: const Key('insight_feedback_latest_choice'),
            style: explainStyle,
          ),
        ],
        if (_justSaved) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            InsightFeedbackCopy.savedLocally,
            key: const Key('insight_feedback_saved_confirmation'),
            style: explainStyle,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          InsightFeedbackCopy.localOnlyNote,
          key: const Key('insight_feedback_local_note'),
          style: explainStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          InsightFeedbackCopy.signalNotFact,
          key: const Key('insight_feedback_signal_note'),
          style: explainStyle,
        ),
      ],
    );
  }
}

class _actionChip extends StatelessWidget {
  const _actionChip({
    required this.label,
    required this.onPressed,
    required this.style,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label, style: style),
    );
  }
}