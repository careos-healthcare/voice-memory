import 'package:flutter/material.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/quick_capture_friction_copy.dart';
import '../features/capacity_loop/quick_capture_friction_models.dart';
import '../features/capacity_loop/quick_capture_friction_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Inline friction check after quick yes capture — fixed options only.
class QuickCaptureFrictionCard extends StatefulWidget {
  const QuickCaptureFrictionCard({
    super.key,
    required this.result,
    this.onSaved,
    this.store,
    this.sampleMode = false,
  });

  const QuickCaptureFrictionCard.test({
    super.key,
    required this.result,
    this.onSaved,
    this.store,
    this.sampleMode = false,
  });

  final QuickCaptureFrictionResult result;
  final VoidCallback? onSaved;
  final QuickCaptureFrictionStore? store;
  final bool sampleMode;

  @override
  State<QuickCaptureFrictionCard> createState() =>
      _QuickCaptureFrictionCardState();
}

class _QuickCaptureFrictionCardState extends State<QuickCaptureFrictionCard> {
  String? _selectedResponseId;
  bool _saving = false;

  QuickCaptureFrictionStore get _store =>
      widget.store ?? QuickCaptureFrictionStore.instance();

  @override
  Widget build(BuildContext context) {
    if (widget.sampleMode ||
        ScreenshotMode.enabled ||
        !widget.result.showCard) {
      return const SizedBox.shrink(
        key: Key('quick_capture_friction_card_hidden'),
      );
    }

    return Container(
      key: const Key('quick_capture_friction_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.title,
            key: const Key('quick_capture_friction_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('quick_capture_friction_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final id in widget.result.responseIds)
            RadioListTile<String>(
              key: Key('quick_capture_friction_option_$id'),
              title: Text(QuickCaptureFrictionCopy.labelForResponse(id)),
              value: id,
              groupValue: _selectedResponseId,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _selectedResponseId = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('quick_capture_friction_save_button'),
            onPressed: _saving || _selectedResponseId == null
                ? null
                : _saveAnswer,
            child: Text(widget.result.primaryCtaLabel),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('quick_capture_friction_skip_button'),
            onPressed: _saving ? null : _skip,
            child: Text(widget.result.secondaryCtaLabel),
          ),
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
      relatedEntryId: widget.result.relatedEntryId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await _store.saveSkipped(relatedEntryId: widget.result.relatedEntryId);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }
}
