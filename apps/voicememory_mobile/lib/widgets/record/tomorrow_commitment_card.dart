import 'package:flutter/material.dart';

import '../../features/tomorrow_return/tomorrow_commitment_coordinator.dart';
import '../../features/tomorrow_return/tomorrow_return_loop_models.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Post-save invitation to commit to returning tomorrow.
class TomorrowCommitmentCard extends StatefulWidget {
  const TomorrowCommitmentCard({
    super.key,
    required this.loop,
    this.onRemindTomorrow,
  });

  final TomorrowReturnLoop loop;

  /// Test hook; defaults to [TomorrowCommitmentCoordinator.saveFromReturnLoop].
  final Future<void> Function(TomorrowReturnLoop loop)? onRemindTomorrow;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  State<TomorrowCommitmentCard> createState() => _TomorrowCommitmentCardState();
}

class _TomorrowCommitmentCardState extends State<TomorrowCommitmentCard> {
  bool _dismissed = false;
  bool _confirmed = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: TomorrowCommitmentCard._warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TomorrowCommitmentCard._warmBorder),
      ),
      child: _confirmed ? _confirmedContent() : _promptContent(),
    );
  }

  Widget _confirmedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                ConsumerUiCopy.tomorrowCommitmentConfirmedLine1,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 17,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ConsumerUiCopy.tomorrowCommitmentConfirmedLine2,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(height: 1.45),
        ),
      ],
    );
  }

  Widget _promptContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ConsumerUiCopy.tomorrowCommitmentLabel,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.warning,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ConsumerUiCopy.tomorrowCommitmentTitle,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(
            fontSize: 17,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ConsumerUiCopy.tomorrowCommitmentBody,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(height: 1.45),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: _saving ? null : _onRemind,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(ConsumerUiCopy.tomorrowCommitmentRemindCta),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: TextButton(
            onPressed: _saving ? null : () => setState(() => _dismissed = true),
            child: const Text(ConsumerUiCopy.tomorrowCommitmentDismissCta),
          ),
        ),
      ],
    );
  }

  Future<void> _onRemind() async {
    setState(() => _saving = true);
    try {
      final save =
          widget.onRemindTomorrow ??
          TomorrowCommitmentCoordinator.saveFromReturnLoop;
      await save(widget.loop);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmed = true;
      });
    }
  }
}
