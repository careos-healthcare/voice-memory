import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/feedback/value_testimonial_store.dart';
import 'package:archiveme_mobile/features/referral/referral_invite_after_value.dart';
import 'package:archiveme_mobile/features/review/review_prompt_after_value.dart';
import 'package:archiveme_mobile/features/share/archive_belief_share_card.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Tiny one-tap feedback row at the bottom of value cards: "Was this
/// useful?" with Yes / Not quite. One tap per card instance, never blocks,
/// never asks for more. Logs only the card type and pre-approved counts —
/// no snippets, belief phrases, or raw content.
///
/// After a Yes, an optional one-field testimonial ask appears below the
/// thanks line ("What felt useful?"). The quote is stored locally only,
/// capped and newline-stripped, never attached to evidence, never logged
/// to analytics, and never surfaces in share cards.
class ValueAccuracyFeedbackRow extends StatefulWidget {
  const ValueAccuracyFeedbackRow({
    required this.cardType, super.key,
    this.entryCount,
    this.hasConnectedThread,
    this.testimonialStore,
  });

  /// Stable id of the host card (e.g. `thread_return_evidence`).
  final String cardType;

  final int? entryCount;
  final bool? hasConnectedThread;

  /// Injectable for tests; defaults to the app-services-backed store.
  final ValueTestimonialStore? testimonialStore;

  static const String question = 'Was this useful?';
  static const String yesLabel = 'Yes';
  static const String notQuiteLabel = 'Not quite';
  static const String yesThanksLine =
      'Thanks — this helps ArchiveMe learn what is useful.';
  static const String notQuiteThanksLine =
      'Thanks — we\u2019ll keep this light.';

  static const String testimonialTitle = 'What felt useful?';
  static const String testimonialPlaceholder =
      'Example: It noticed something I keep repeating.';
  static const String testimonialHelper =
      'Do not include anything private. This is saved as feedback only.';
  static const String testimonialSaveLabel = 'Save feedback';
  static const String testimonialNotNowLabel = 'Not now';
  static const String testimonialThanksLine =
      'Thanks — this helps us improve ArchiveMe.';

  @override
  State<ValueAccuracyFeedbackRow> createState() =>
      _ValueAccuracyFeedbackRowState();
}

class _ValueAccuracyFeedbackRowState extends State<ValueAccuracyFeedbackRow> {
  bool? _saidUseful;
  bool _askDismissed = false;
  bool _testimonialSaved = false;
  final TextEditingController _quoteController = TextEditingController();

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }

  void _submit(bool useful) {
    if (_saidUseful != null) return;
    setState(() => _saidUseful = useful);
    // Session value signal for the referral invite — card type only, never
    // content. A "Not quite" suppresses the invite for the session.
    ReferralInviteAfterValue.recordValueFeedback(
      cardType: widget.cardType,
      useful: useful,
    );
    // The same signal gates the App Store review prompt.
    ReviewPromptAfterValue.recordValueFeedback(
      cardType: widget.cardType,
      useful: useful,
    );
    // And the user-approved belief share card.
    ArchiveBeliefShareCard.recordValueFeedback(
      cardType: widget.cardType,
      useful: useful,
    );
    ActivationFunnelAnalytics.track(
      useful
          ? ActivationFunnelAnalytics.valueFeedbackUseful
          : ActivationFunnelAnalytics.valueFeedbackNotQuite,
      cardType: widget.cardType,
      entryCount: widget.entryCount,
      hasConnectedThread: widget.hasConnectedThread,
    );
  }

  Future<void> _saveTestimonial() async {
    final quote = ValueTestimonialStore.sanitizeQuote(_quoteController.text);
    if (quote.isEmpty) {
      // Nothing typed — treat as a quiet "not now".
      setState(() => _askDismissed = true);
      return;
    }
    setState(() => _testimonialSaved = true);
    // Metadata only — the quote itself never enters analytics.
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.valueTestimonialSaved,
      cardType: widget.cardType,
      entryCount: widget.entryCount,
      hasConnectedThread: widget.hasConnectedThread,
    );
    final store =
        widget.testimonialStore ?? ValueTestimonialStore.instanceOrNull();
    await store?.add(quote: quote, cardType: widget.cardType);
  }

  @override
  Widget build(BuildContext context) {
    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary);

    final answered = _saidUseful;
    if (answered != null) {
      return Padding(
        key: Key('value_feedback_thanks_${widget.cardType}'),
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              answered
                  ? ValueAccuracyFeedbackRow.yesThanksLine
                  : ValueAccuracyFeedbackRow.notQuiteThanksLine,
              style: helperStyle,
            ),
            if (answered && _testimonialSaved)
              Padding(
                key: Key('value_testimonial_thanks_${widget.cardType}'),
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  ValueAccuracyFeedbackRow.testimonialThanksLine,
                  style: helperStyle,
                ),
              )
            else if (answered && !_askDismissed)
              _testimonialAsk(context, helperStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(ValueAccuracyFeedbackRow.question, style: helperStyle),
          ),
          _chip(
            context,
            key: Key('value_feedback_yes_${widget.cardType}'),
            label: ValueAccuracyFeedbackRow.yesLabel,
            onTap: () => _submit(true),
          ),
          const SizedBox(width: AppSpacing.xs),
          _chip(
            context,
            key: Key('value_feedback_not_quite_${widget.cardType}'),
            label: ValueAccuracyFeedbackRow.notQuiteLabel,
            onTap: () => _submit(false),
          ),
        ],
      ),
    );
  }

  /// Optional one-field testimonial ask under the yes-thanks line. Single
  /// line (no newlines possible), capped input, and a clear way out.
  Widget _testimonialAsk(BuildContext context, TextStyle helperStyle) {
    return Padding(
      key: Key('value_testimonial_ask_${widget.cardType}'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ValueAccuracyFeedbackRow.testimonialTitle,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: Key('value_testimonial_field_${widget.cardType}'),
            controller: _quoteController,
            maxLength: ValueTestimonialStore.maxQuoteLength,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: ValueAccuracyFeedbackRow.testimonialPlaceholder,
              hintStyle: helperStyle,
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(ValueAccuracyFeedbackRow.testimonialHelper, style: helperStyle),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _chip(
                context,
                key: Key('value_testimonial_save_${widget.cardType}'),
                label: ValueAccuracyFeedbackRow.testimonialSaveLabel,
                onTap: _saveTestimonial,
              ),
              _chip(
                context,
                key: Key('value_testimonial_not_now_${widget.cardType}'),
                label: ValueAccuracyFeedbackRow.testimonialNotNowLabel,
                onTap: () => setState(() => _askDismissed = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}