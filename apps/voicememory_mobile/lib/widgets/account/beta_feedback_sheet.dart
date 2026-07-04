import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_feedback/beta_feedback_analytics.dart';
import '../../features/beta_feedback/beta_feedback_controller.dart';
import '../../features/beta_feedback/beta_feedback_copy.dart';
import '../../features/beta_feedback/beta_feedback_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Structured beta feedback sheet — lightweight TestFlight feedback.
class BetaFeedbackSheet extends StatefulWidget {
  const BetaFeedbackSheet({
    super.key,
    required this.source,
    required this.entryCount,
    this.controller = const BetaFeedbackController(),
  });

  final String source;
  final int entryCount;
  final BetaFeedbackController controller;

  static Future<void> show(
    BuildContext context, {
    required String source,
    required int entryCount,
    BetaFeedbackController? controller,
  }) {
    BetaFeedbackAnalytics.opened(source: source, entryCount: entryCount);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: BetaFeedbackSheet(
          source: source,
          entryCount: entryCount,
          controller: controller ?? const BetaFeedbackController(),
        ),
      ),
    );
  }

  @override
  State<BetaFeedbackSheet> createState() => _BetaFeedbackSheetState();
}

class _BetaFeedbackSheetState extends State<BetaFeedbackSheet> {
  BetaFeedbackOptionType? _selected;
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final option = _selected;
    if (option == null || _submitting) return;
    setState(() => _submitting = true);
    final submission = await widget.controller.buildSubmission(
      source: widget.source,
      option: option,
      entryCount: widget.entryCount,
      note: _noteController.text,
    );
    if (!mounted) return;
    final outcome = await widget.controller.submit(
      context: context,
      submission: submission,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (outcome != BetaFeedbackSubmitOutcome.cancelled) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('beta_feedback_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BetaFeedbackCopy.sheetTitle,
                key: const Key('beta_feedback_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                BetaFeedbackCopy.sheetSubtitle,
                key: const Key('beta_feedback_sheet_subtitle'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final option in BetaFeedbackOptionType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: RadioListTile<BetaFeedbackOptionType>(
                    key: Key('beta_feedback_option_${option.name}'),
                    value: option,
                    groupValue: _selected,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _selected = value),
                    title: Text(
                      option.label,
                      style: ArchiveMobileTypography.explanationBody(context),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('beta_feedback_sheet_note'),
                controller: _noteController,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: BetaFeedbackCopy.sheetNoteLabel,
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('beta_feedback_sheet_send'),
                onPressed: _selected != null && !_submitting ? _submit : null,
                child: const Text(BetaFeedbackCopy.sheetSendCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small inline link to open the beta feedback sheet.
class BetaFeedbackLink extends StatelessWidget {
  const BetaFeedbackLink({
    super.key,
    required this.source,
    required this.entryCount,
    this.controller,
    this.align = Alignment.centerLeft,
  });

  final String source;
  final int entryCount;
  final BetaFeedbackController? controller;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align,
      child: TextButton(
        key: Key('beta_feedback_link_$source'),
        onPressed: () => BetaFeedbackSheet.show(
          context,
          source: source,
          entryCount: entryCount,
          controller: controller,
        ),
        child: const Text(BetaFeedbackCopy.sheetLinkLabel),
      ),
    );
  }
}
