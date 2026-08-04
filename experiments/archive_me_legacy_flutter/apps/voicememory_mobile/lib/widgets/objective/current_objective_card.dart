import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/objective/current_objective_model.dart';
import '../../features/objective/current_objective_snapshot_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Compact card showing what to do next — today's check or record moment.
class CurrentObjectiveCard extends StatefulWidget {
  const CurrentObjectiveCard({
    super.key,
    required this.objective,
    this.onPrimaryTap,
    this.onSecondaryTap,
    this.compact = false,
    this.persistSnapshot = true,
    this.showRecordCta = true,
  });

  final CurrentObjective objective;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;
  final bool compact;
  final bool persistSnapshot;
  final bool showRecordCta;

  @override
  State<CurrentObjectiveCard> createState() => _CurrentObjectiveCardState();
}

class _CurrentObjectiveCardState extends State<CurrentObjectiveCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackShown();
  }

  @override
  void didUpdateWidget(covariant CurrentObjectiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objective.type != widget.objective.type) {
      _tracked = false;
      _trackShown();
    }
  }

  void _trackShown() {
    if (_tracked) return;
    _tracked = true;
    ActivationTracker.trackCurrentObjectiveShown(widget.objective.typeId);
    if (widget.persistSnapshot) {
      unawaited(_persistSnapshot(widget.objective));
    }
  }

  Future<void> _persistSnapshot(CurrentObjective objective) async {
    await CurrentObjectiveSnapshotStore.instance().saveSnapshot(objective);
  }

  void _onPrimary() {
    ActivationTracker.trackCurrentObjectivePrimaryTapped();
    widget.onPrimaryTap?.call();
  }

  void _onSecondary() {
    ActivationTracker.trackCurrentObjectiveSecondaryTapped();
    widget.onSecondaryTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.objective;
    final compact = widget.compact;
    final padding = compact ? AppSpacing.sm : AppSpacing.md;
    final titleSize = compact ? 15.0 : 17.0;
    final bodySize = compact ? 13.0 : 14.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(
          color: o.type == CurrentObjectiveType.answerTodayCheck
              ? AppColors.accentPrimary.withValues(alpha: 0.4)
              : _warmBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            o.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: titleSize,
            ),
          ),
          SizedBox(height: compact ? 4 : AppSpacing.sm),
          Text(
            o.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: bodySize, height: 1.45),
          ),
          if (o.checkQuestion != null &&
              o.checkQuestion!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            Text(
              o.checkQuestion!,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ],
          if (widget.showRecordCta && widget.onPrimaryTap != null) ...[
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: compact ? 40 : 44,
              child: FilledButton(
                onPressed: _onPrimary,
                child: Text(o.primaryCtaLabel),
              ),
            ),
          ],
          if (o.secondaryCtaLabel != null && widget.onSecondaryTap != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _onSecondary,
                child: Text(o.secondaryCtaLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
