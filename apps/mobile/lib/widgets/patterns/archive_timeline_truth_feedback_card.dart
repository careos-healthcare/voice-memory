import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_change_timeline_metrics_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Lightweight beta truth question after timeline engagement.
class ArchiveTimelineTruthFeedbackCard extends StatefulWidget {
  const ArchiveTimelineTruthFeedbackCard({
    required this.store, super.key,
    this.onAnswered,
  });

  final ArchiveChangeTimelineMetricsStore store;
  final VoidCallback? onAnswered;

  @override
  State<ArchiveTimelineTruthFeedbackCard> createState() =>
      _ArchiveTimelineTruthFeedbackCardState();
}

class _ArchiveTimelineTruthFeedbackCardState
    extends State<ArchiveTimelineTruthFeedbackCard> {
  ArchiveTimelineTruthFeedback? _selected;
  bool _showNote = false;
  final _noteController = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(ArchiveTimelineTruthFeedback feedback) async {
    setState(() {
      _selected = feedback;
      _showNote = feedback != ArchiveTimelineTruthFeedback.yes;
    });
    if (feedback == ArchiveTimelineTruthFeedback.yes) {
      await widget.store.saveTruthFeedback(feedback: feedback);
      setState(() => _saved = true);
      widget.onAnswered?.call();
    }
  }

  Future<void> _saveNote() async {
    if (_selected == null) return;
    await widget.store.saveTruthFeedback(
      feedback: _selected!,
      note: _noteController.text,
    );
    setState(() => _saved = true);
    widget.onAnswered?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) {
      return Text(
        'Thanks — that helps ArchiveMe stay closer to your experience.',
        key: const Key('archive_timeline_truth_feedback_thanks'),
        style: ArchiveMobileTypography.responsiveHelper(context),
      );
    }

    return Container(
      key: const Key('archive_timeline_truth_feedback_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Did this feel true?',
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _chip(
                key: const Key('archive_timeline_truth_yes'),
                label: 'Yes',
                selected: _selected == ArchiveTimelineTruthFeedback.yes,
                onTap: () => _submit(ArchiveTimelineTruthFeedback.yes),
              ),
              _chip(
                key: const Key('archive_timeline_truth_partly'),
                label: 'Partly',
                selected: _selected == ArchiveTimelineTruthFeedback.partly,
                onTap: () => _submit(ArchiveTimelineTruthFeedback.partly),
              ),
              _chip(
                key: const Key('archive_timeline_truth_not_really'),
                label: 'Not really',
                selected: _selected == ArchiveTimelineTruthFeedback.notReally,
                onTap: () => _submit(ArchiveTimelineTruthFeedback.notReally),
              ),
            ],
          ),
          if (_showNote) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('archive_timeline_truth_note'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'What was wrong? (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onSubmitted: (_) => _saveNote(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('archive_timeline_truth_save'),
                onPressed: _saveNote,
                child: const Text('Send'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      key: key,
      label: Text(label),
      backgroundColor: selected ? AppColors.accentLight : Colors.white,
      side: BorderSide(
        color: selected ? AppColors.accentPrimary : AppColors.borderSubtle,
      ),
      onPressed: onTap,
    );
  }
}