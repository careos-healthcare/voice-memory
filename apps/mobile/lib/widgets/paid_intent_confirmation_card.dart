import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/paid_intent/paid_intent_confirmation_copy.dart';
import 'package:archiveme_mobile/features/paid_intent/paid_intent_confirmation_models.dart';
import 'package:archiveme_mobile/features/paid_intent/paid_intent_confirmation_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Local paid intent confirmation card — no payment flow.
class PaidIntentConfirmationCard extends StatefulWidget {
  const PaidIntentConfirmationCard({
    required this.result, required this.valueSignals, super.key,
    this.store,
    this.compact = false,
    this.onSaved,
    this.sampleMode = false,
  });

  const PaidIntentConfirmationCard.test({
    required this.result, required this.valueSignals, super.key,
    this.store,
    this.compact = false,
    this.onSaved,
    this.sampleMode = false,
  });

  final PaidIntentConfirmationResult result;
  final PaidIntentValueSignalsAtResponse valueSignals;
  final PaidIntentConfirmationStore? store;
  final bool compact;
  final VoidCallback? onSaved;
  final bool sampleMode;

  @override
  State<PaidIntentConfirmationCard> createState() =>
      _PaidIntentConfirmationCardState();
}

class _PaidIntentConfirmationCardState
    extends State<PaidIntentConfirmationCard> {
  String? _selectedLabel;
  bool _saving = false;

  PaidIntentConfirmationStore get _store =>
      widget.store ?? PaidIntentConfirmationStore.instance();

  @override
  Widget build(BuildContext context) {
    if (widget.sampleMode ||
        ScreenshotMode.enabled ||
        (!widget.result.showCard &&
            widget.result.answeredSummaryLine.isEmpty)) {
      return const SizedBox.shrink(
        key: Key('paid_intent_confirmation_card_hidden'),
      );
    }

    if (!widget.result.showCard &&
        widget.result.answeredSummaryLine.isNotEmpty) {
      return Text(
        widget.result.answeredSummaryLine,
        key: const Key('paid_intent_confirmation_answered_line'),
        style: ArchiveMobileTypography.explanationBody(context),
      );
    }

    if (!widget.result.showCard) {
      return const SizedBox.shrink(
        key: Key('paid_intent_confirmation_card_hidden'),
      );
    }

    return Container(
      key: const Key('paid_intent_confirmation_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: widget.compact
          ? VoiceMemoryCards.standard(background: AppColors.surfaceAlt)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.title,
            key: const Key('paid_intent_confirmation_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('paid_intent_confirmation_body'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.question,
            key: const Key('paid_intent_confirmation_question'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...[
            for (final label in widget.result.responseOptions)
              RadioListTile<String>(
                key: Key(
                  'paid_intent_confirmation_option_${PaidIntentConfirmationCopy.responseIdForLabel(label)}',
                ),
                title: Text(label),
                value: label,
                groupValue: _selectedLabel,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedLabel = value),
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            PaidIntentConfirmationCopy.noPaymentNote,
            key: const Key('paid_intent_confirmation_no_payment_note'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('paid_intent_confirmation_save_button'),
            onPressed: _saving || _selectedLabel == null ? null : _saveAnswer,
            child: Text(widget.result.primaryCtaLabel),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('paid_intent_confirmation_skip_button'),
            onPressed: _saving ? null : _skip,
            child: Text(widget.result.secondaryCtaLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAnswer() async {
    final label = _selectedLabel;
    if (label == null) return;
    final responseId = PaidIntentConfirmationCopy.responseIdForLabel(label);
    if (responseId.isEmpty) return;
    setState(() => _saving = true);
    await _store.saveAnswered(
      responseId: responseId,
      valueSignals: widget.valueSignals,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await _store.saveSkipped(valueSignals: widget.valueSignals);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }
}