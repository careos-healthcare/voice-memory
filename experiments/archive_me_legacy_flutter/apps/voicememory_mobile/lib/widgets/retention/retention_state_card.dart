import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/retention/retention_state_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Compact status card for tomorrow's check retention loop.
class RetentionStateCard extends StatefulWidget {
  const RetentionStateCard({
    super.key,
    required this.state,
    this.checkWhyThisCheck,
    this.checkExampleAnswer,
    this.onPrimaryTap,
    this.onSecondaryTap,
    this.onDismiss,
  });

  final RetentionState state;
  final String? checkWhyThisCheck;
  final String? checkExampleAnswer;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onDismiss;

  @override
  State<RetentionStateCard> createState() => _RetentionStateCardState();
}

class _RetentionStateCardState extends State<RetentionStateCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackShown();
  }

  @override
  void didUpdateWidget(covariant RetentionStateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.type != widget.state.type) {
      _tracked = false;
      _trackShown();
    }
  }

  void _trackShown() {
    if (_tracked) return;
    _tracked = true;
    ActivationTracker.trackRetentionStateShown();
    switch (widget.state.type) {
      case RetentionStateType.checkDueToday:
        ActivationTracker.trackRetentionDueShown();
      case RetentionStateType.checkSetForTomorrow:
        ActivationTracker.trackRetentionCheckSetShown();
      case RetentionStateType.loopClosed:
        ActivationTracker.trackRetentionLoopClosedShown();
      case RetentionStateType.nextCheckChosen:
        ActivationTracker.trackRetentionNextCheckReady();
      case RetentionStateType.checkMissed:
        ActivationTracker.trackRetentionMissedCheck();
      case RetentionStateType.noCheckSet:
        break;
    }
  }

  void _onPrimary() {
    ActivationTracker.trackRetentionPrimaryCtaTapped();
    widget.onPrimaryTap?.call();
    if (widget.state.type == RetentionStateType.nextCheckChosen) {
      widget.onDismiss?.call();
    }
  }

  void _onSecondary() {
    ActivationTracker.trackRetentionSecondaryCtaTapped();
    widget.onSecondaryTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final compact = state.compact;
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
          color: state.type == RetentionStateType.checkDueToday
              ? AppColors.accentPrimary.withValues(alpha: 0.4)
              : _warmBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.urgencyLabel != null) ...[
            Text(
              state.urgencyLabel!,
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.accentPrimary,
              ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          ],
          Text(
            state.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: titleSize,
            ),
          ),
          if (!compact || state.type != RetentionStateType.nextCheckChosen) ...[
            SizedBox(height: compact ? 4 : AppSpacing.sm),
            Text(
              state.body,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: bodySize, height: 1.45),
            ),
          ],
          if (state.checkQuestion != null &&
              state.checkQuestion!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            Text(
              state.checkQuestion!,
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
          if (!compact &&
              widget.checkWhyThisCheck != null &&
              (state.type == RetentionStateType.checkSetForTomorrow ||
                  state.type == RetentionStateType.checkDueToday)) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              widget.checkWhyThisCheck!,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 13, height: 1.45),
            ),
          ],
          if (!compact &&
              widget.checkExampleAnswer != null &&
              (state.type == RetentionStateType.checkSetForTomorrow ||
                  state.type == RetentionStateType.checkDueToday)) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              'Example: ${widget.checkExampleAnswer!}',
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(
                    fontSize: 12,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
          if (widget.onPrimaryTap != null) ...[
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: compact ? 40 : 44,
              child: FilledButton(
                onPressed: _onPrimary,
                child: Text(state.primaryCtaLabel),
              ),
            ),
          ],
          if (state.secondaryCtaLabel != null &&
              widget.onSecondaryTap != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _onSecondary,
                child: Text(state.secondaryCtaLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
