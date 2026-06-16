import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/prove_enough/prove_enough_post_record_engine.dart';
import '../../features/prove_enough/prove_enough_stop_cost_store.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Stop-cost reflection prompt after a prove_enough recording.
class StopCostPromptCard extends StatefulWidget {
  const StopCostPromptCard({
    super.key,
    required this.entryId,
    this.onAnswered,
    @visibleForTesting this.stopCostStore,
    @visibleForTesting this.skipInitialLoad = false,
  });

  final String entryId;
  final VoidCallback? onAnswered;

  @visibleForTesting
  final ProveEnoughStopCostStore? stopCostStore;

  @visibleForTesting
  final bool skipInitialLoad;

  @override
  State<StopCostPromptCard> createState() => _StopCostPromptCardState();
}

class _StopCostPromptCardState extends State<StopCostPromptCard> {
  String? _savedAnswer;
  bool _loading = true;

  ProveEnoughStopCostStore get _store =>
      widget.stopCostStore ?? ProveEnoughStopCostStore.instance();

  @override
  void initState() {
    super.initState();
    if (widget.skipInitialLoad) {
      _loading = false;
      return;
    }
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _store.load(widget.entryId);
    if (!mounted) return;
    setState(() {
      _savedAnswer = saved;
      _loading = false;
    });
  }

  Future<void> _openAnswerSheet() async {
    final controller = TextEditingController(text: _savedAnswer ?? '');
    final answer = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.sm,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What would have happened if you stopped?',
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ProveEnoughPostRecordEngine.imaginedStopCostPrompt,
                style: ArchiveMobileTypography.body(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Write a short note…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.of(context).pop(text);
                },
                child: const Text('Save answer'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (answer == null || answer.trim().isEmpty) return;

    await _store.save(entryId: widget.entryId, answer: answer);
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.stopCostPromptAnswered,
    );
    if (!mounted) return;
    setState(() => _savedAnswer = answer.trim());
    widget.onAnswered?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFDF8F3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What would have happened if you stopped?',
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProveEnoughPostRecordEngine.imaginedStopCostPrompt,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          if (_savedAnswer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _savedAnswer!,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('stop_cost_answer_cta'),
            onPressed: _openAnswerSheet,
            child: Text(_savedAnswer == null ? 'Answer this' : 'Edit answer'),
          ),
        ],
      ),
    );
  }
}
