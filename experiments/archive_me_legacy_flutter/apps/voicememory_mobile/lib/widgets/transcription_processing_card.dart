import 'package:flutter/material.dart';

import '../features/transcription_queue/transcription_job.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class TranscriptionProcessingCard extends StatefulWidget {
  const TranscriptionProcessingCard({
    required this.job,
    this.onUseTypedText,
    super.key,
  });

  final TranscriptionJob job;
  final VoidCallback? onUseTypedText;

  @override
  State<TranscriptionProcessingCard> createState() =>
      _TranscriptionProcessingCardState();
}

class _TranscriptionProcessingCardState
    extends State<TranscriptionProcessingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.job.status == TranscriptionJobStatus.failed;
    final waiting = widget.job.status == TranscriptionJobStatus.retryWaiting;
    final status = failed
        ? 'Transcription needs another try'
        : waiting
        ? 'Waiting to retry transcription'
        : 'Processing audio (${_duration(widget.job.durationSeconds)})…';
    return Semantics(
      container: true,
      liveRegion: true,
      label: status,
      child: Card(
        key: Key('transcription_job_${widget.job.id}'),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FadeTransition(
                    opacity: _pulse,
                    child: Icon(
                      failed ? Icons.error_outline : Icons.graphic_eq,
                      color: failed ? AppColors.error : AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _skeleton(widthFactor: .92),
              const SizedBox(height: AppSpacing.xs),
              _skeleton(widthFactor: .68),
              if (widget.onUseTypedText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: widget.onUseTypedText,
                  child: const Text('Add text instead'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeleton({required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: FadeTransition(
        opacity: _pulse,
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.borderSubtle.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }

  static String _duration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
