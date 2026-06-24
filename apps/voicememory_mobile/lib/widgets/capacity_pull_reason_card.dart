import 'package:flutter/material.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_pull_reason_copy.dart';
import '../features/capacity_loop/capacity_pull_reason_models.dart';
import '../features/capacity_loop/capacity_pull_reason_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Archive Home card for pull reasons — fixed reason ids only.
class CapacityPullReasonCard extends StatefulWidget {
  const CapacityPullReasonCard({
    super.key,
    required this.result,
    this.onSaved,
    this.store,
    this.sampleMode = false,
  });

  const CapacityPullReasonCard.test({
    super.key,
    required this.result,
    this.onSaved,
    CapacityPullReasonStore? store,
    this.sampleMode = false,
  }) : store = store;

  final CapacityPullReasonResult result;
  final VoidCallback? onSaved;
  final CapacityPullReasonStore? store;
  final bool sampleMode;

  @override
  State<CapacityPullReasonCard> createState() => _CapacityPullReasonCardState();
}

class _CapacityPullReasonCardState extends State<CapacityPullReasonCard> {
  bool _expanded = false;
  final Set<String> _selectedReasons = {};
  bool _saving = false;

  CapacityPullReasonStore get _store =>
      widget.store ?? CapacityPullReasonStore.instance();

  @override
  Widget build(BuildContext context) {
    if (widget.sampleMode ||
        ScreenshotMode.enabled ||
        !widget.result.hasCard ||
        !widget.result.showOnArchiveHome) {
      return const SizedBox.shrink(
        key: Key('capacity_pull_reason_card_hidden'),
      );
    }

    return Container(
      key: const Key('capacity_pull_reason_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.title,
            key: const Key('capacity_pull_reason_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('capacity_pull_reason_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final id in CapacityPullReasonIds.all)
                  FilterChip(
                    key: Key('capacity_pull_reason_$id'),
                    label: Text(CapacityPullReasonCopy.labelForReason(id)),
                    selected: _selectedReasons.contains(id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedReasons.add(id);
                        } else {
                          _selectedReasons.remove(id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('capacity_pull_reason_save_button'),
              onPressed: _saving || _selectedReasons.isEmpty ? null : _saveAnswer,
              child: Text(CapacityPullReasonCopy.saveReasonCta),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const Key('capacity_pull_reason_primary_button'),
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(widget.result.primaryCtaLabel),
                ),
                OutlinedButton(
                  key: const Key('capacity_pull_reason_skip_button'),
                  onPressed: _saving ? null : _skip,
                  child: Text(widget.result.secondaryCtaLabel),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveAnswer() async {
    if (_selectedReasons.isEmpty) return;
    setState(() => _saving = true);
    await _store.saveAnswered(
      sourceEntryId: widget.result.pendingEntryId,
      reasonIds: _selectedReasons.toList(),
    );
    if (!mounted) return;
    widget.onSaved?.call();
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await _store.saveSkipped(sourceEntryId: widget.result.pendingEntryId);
    if (!mounted) return;
    widget.onSaved?.call();
  }
}
