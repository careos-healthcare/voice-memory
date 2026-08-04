import 'package:flutter/material.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_cost_copy.dart';
import '../features/capacity_loop/capacity_cost_models.dart';
import '../features/capacity_loop/capacity_cost_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Archive Home card for later-cost check-ins — cost types only, no journal text.
class CapacityCostLaterCard extends StatefulWidget {
  const CapacityCostLaterCard({
    super.key,
    required this.result,
    this.onSaved,
    this.store,
    this.sampleMode = false,
  });

  const CapacityCostLaterCard.test({
    super.key,
    required this.result,
    this.onSaved,
    this.store,
    this.sampleMode = false,
  });

  final CapacityCostCheckinResult result;
  final VoidCallback? onSaved;
  final CapacityCostStore? store;
  final bool sampleMode;

  @override
  State<CapacityCostLaterCard> createState() => _CapacityCostLaterCardState();
}

class _CapacityCostLaterCardState extends State<CapacityCostLaterCard> {
  bool _expanded = false;
  final Set<String> _selected = {};
  bool _saving = false;

  CapacityCostStore get _store => widget.store ?? CapacityCostStore.instance();

  @override
  Widget build(BuildContext context) {
    if (widget.sampleMode ||
        ScreenshotMode.enabled ||
        !widget.result.hasCard ||
        !widget.result.showOnArchiveHome) {
      return const SizedBox.shrink(key: Key('capacity_cost_later_card_hidden'));
    }

    return Container(
      key: const Key('capacity_cost_later_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.title,
            key: const Key('capacity_cost_later_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('capacity_cost_later_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.helperText,
            key: const Key('capacity_cost_later_card_helper'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final id in CapacityCostTypeIds.all)
                  FilterChip(
                    key: Key('capacity_cost_type_$id'),
                    label: Text(CapacityCostCopy.labelForCostType(id)),
                    selected: _selected.contains(id),
                    onSelected: (_) => _toggleType(id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('capacity_cost_later_save_button'),
              onPressed: _saving || _selected.isEmpty ? null : _saveAnswer,
              child: Text(CapacityCostCopy.saveCheckinCta),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const Key('capacity_cost_later_primary_button'),
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(widget.result.primaryCtaLabel),
                ),
                OutlinedButton(
                  key: const Key('capacity_cost_later_skip_button'),
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

  void _toggleType(String id) {
    setState(() {
      if (id == CapacityCostTypeIds.none) {
        _selected
          ..clear()
          ..add(id);
        return;
      }
      _selected.remove(CapacityCostTypeIds.none);
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _saveAnswer() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    await _store.saveAnswered(
      sourceEntryId: widget.result.pendingEntryId,
      costTypeIds: _selected.toList(),
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
