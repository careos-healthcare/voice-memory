import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Archive Home card for decision outcomes — outcome ids only, no journal text.
class CapacityDecisionOutcomeCard extends StatefulWidget {
  const CapacityDecisionOutcomeCard({
    required this.result, super.key,
    this.onSaved,
    this.store,
    this.sampleMode = false,
  });

  const CapacityDecisionOutcomeCard.test({
    required this.result, super.key,
    this.onSaved,
    this.store,
    this.sampleMode = false,
  });

  final CapacityDecisionOutcomeResult result;
  final VoidCallback? onSaved;
  final CapacityDecisionOutcomeStore? store;
  final bool sampleMode;

  @override
  State<CapacityDecisionOutcomeCard> createState() =>
      _CapacityDecisionOutcomeCardState();
}

class _CapacityDecisionOutcomeCardState
    extends State<CapacityDecisionOutcomeCard> {
  bool _expanded = false;
  String? _selectedOutcome;
  bool _saving = false;

  CapacityDecisionOutcomeStore get _store =>
      widget.store ?? CapacityDecisionOutcomeStore.instance();

  @override
  Widget build(BuildContext context) {
    if (widget.sampleMode ||
        ScreenshotMode.enabled ||
        !widget.result.hasCard ||
        !widget.result.showOnArchiveHome) {
      return const SizedBox.shrink(
        key: Key('capacity_decision_outcome_card_hidden'),
      );
    }

    return Container(
      key: const Key('capacity_decision_outcome_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.title,
            key: const Key('capacity_decision_outcome_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('capacity_decision_outcome_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.helperText,
            key: const Key('capacity_decision_outcome_card_helper'),
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
                for (final id in CapacityDecisionOutcomeIds.all)
                  FilterChip(
                    key: Key('capacity_decision_outcome_$id'),
                    label: Text(
                      CapacityDecisionOutcomeCopy.labelForOutcome(id),
                    ),
                    selected: _selectedOutcome == id,
                    onSelected: (_) => setState(() => _selectedOutcome = id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('capacity_decision_outcome_save_button'),
              onPressed: _saving || _selectedOutcome == null
                  ? null
                  : _saveAnswer,
              child: const Text(CapacityDecisionOutcomeCopy.saveOutcomeCta),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const Key('capacity_decision_outcome_primary_button'),
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(widget.result.primaryCtaLabel),
                ),
                OutlinedButton(
                  key: const Key('capacity_decision_outcome_skip_button'),
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
    final outcome = _selectedOutcome;
    if (outcome == null) return;
    setState(() => _saving = true);
    await _store.saveAnswered(
      sourceEntryId: widget.result.pendingEntryId,
      outcomeId: outcome,
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