import 'package:flutter/material.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_activation_fit_copy.dart';
import '../features/capacity_loop/capacity_activation_fit_models.dart';
import '../features/capacity_loop/capacity_activation_fit_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Archive Home / Capacity Loop card for activation fit — fixed options only.
class CapacityActivationFitCard extends StatefulWidget {
  const CapacityActivationFitCard({
    super.key,
    required this.result,
    this.onSaved,
    this.store,
    this.sampleMode = false,
    this.compact = false,
    this.showOnSurface = true,
  });

  const CapacityActivationFitCard.test({
    super.key,
    required this.result,
    this.onSaved,
    CapacityActivationFitStore? store,
    this.sampleMode = false,
    this.compact = false,
    this.showOnSurface = true,
  }) : store = store;

  final CapacityActivationFitResult result;
  final VoidCallback? onSaved;
  final CapacityActivationFitStore? store;
  final bool sampleMode;
  final bool compact;
  final bool showOnSurface;

  @override
  State<CapacityActivationFitCard> createState() =>
      _CapacityActivationFitCardState();
}

class _CapacityActivationFitCardState extends State<CapacityActivationFitCard> {
  bool _expanded = false;
  String? _selectedResponseId;
  bool _saving = false;

  CapacityActivationFitStore get _store =>
      widget.store ?? CapacityActivationFitStore.instance();

  @override
  Widget build(BuildContext context) {
    if (widget.sampleMode ||
        ScreenshotMode.enabled ||
        !widget.result.hasCard ||
        !widget.showOnSurface) {
      return const SizedBox.shrink(
        key: Key('capacity_activation_fit_card_hidden'),
      );
    }

    final expanded = !widget.compact || _expanded;

    return Container(
      key: const Key('capacity_activation_fit_card'),
      width: double.infinity,
      margin: widget.compact
          ? const EdgeInsets.only(bottom: AppSpacing.md)
          : EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: widget.compact
          ? VoiceMemoryCards.standard(background: AppColors.surfaceAlt)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.title,
            key: const Key('capacity_activation_fit_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('capacity_activation_fit_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            ...[
              for (final id in CapacityActivationFitResponseIds.all)
                RadioListTile<String>(
                  key: Key('capacity_activation_fit_option_$id'),
                  title: Text(CapacityActivationFitCopy.labelForResponse(id)),
                  value: id,
                  groupValue: _selectedResponseId,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selectedResponseId = value),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('capacity_activation_fit_save_button'),
              onPressed:
                  _saving || _selectedResponseId == null ? null : _saveAnswer,
              child: Text(widget.result.primaryCtaLabel),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('capacity_activation_fit_skip_button'),
              onPressed: _saving ? null : _skip,
              child: Text(widget.result.secondaryCtaLabel),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const Key('capacity_activation_fit_primary_button'),
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(widget.result.primaryCtaLabel),
                ),
                OutlinedButton(
                  key: const Key('capacity_activation_fit_skip_button'),
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
    final responseId = _selectedResponseId;
    if (responseId == null || responseId.isEmpty) return;
    setState(() => _saving = true);
    await _store.saveAnswered(
      responseId: responseId,
      activationEntryCount: widget.result.activationEntryCount,
    );
    if (!mounted) return;
    widget.onSaved?.call();
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await _store.saveSkipped(
      activationEntryCount: widget.result.activationEntryCount,
    );
    if (!mounted) return;
    widget.onSaved?.call();
  }
}
