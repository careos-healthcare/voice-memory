import 'dart:async';

import 'package:flutter/material.dart';

import '../../billing/paywall_rejection_reason.dart';
import '../../design/archive_mobile_typography.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// One-tap bottom-sheet question after a paywall dismissal: "What held you
/// back?" Five stable reasons plus Skip. Optional and non-blocking — any
/// path out (reason, Skip, swipe, barrier) closes it immediately, and only
/// the stable reason id is ever logged.
class PaywallRejectionPrompt extends StatefulWidget {
  const PaywallRejectionPrompt({super.key, this.source, this.onReason});

  /// Paywall source id for attribution (e.g. `value_moment`). Never user text.
  final String? source;

  /// Called with the chosen reason — lets the opener persist the stable id
  /// (e.g. for the objection follow-up on a later paywall visit).
  final ValueChanged<PaywallRejectionReason>? onReason;

  /// Sheet results so the caller can tell an explicit close from a
  /// barrier/swipe dismissal (which it should count as a skip).
  static const String resultAnswered = 'answered';
  static const String resultSkipped = 'skipped';

  @override
  State<PaywallRejectionPrompt> createState() => _PaywallRejectionPromptState();
}

class _PaywallRejectionPromptState extends State<PaywallRejectionPrompt> {
  bool _answered = false;
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _selectReason(PaywallRejectionReason reason) {
    if (_answered) return;
    setState(() => _answered = true);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.paywallRejectionReasonSelected,
      reason: reason.id,
      source: widget.source,
    );
    widget.onReason?.call(reason);
    // Brief thanks, then the sheet closes itself — nothing else to do.
    _closeTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).maybePop(PaywallRejectionPrompt.resultAnswered);
    });
  }

  void _skip() {
    if (_answered) return;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.paywallRejectionPromptSkipped,
      source: widget.source,
    );
    Navigator.of(context).maybePop(PaywallRejectionPrompt.resultSkipped);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Scroll-safe on any screen height — the sheet may open on small
      // devices and must never overflow or trap the user.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: _answered ? _thanksBody(context) : _questionBody(context),
      ),
    );
  }

  Widget _thanksBody(BuildContext context) {
    return Padding(
      key: const Key('paywall_rejection_thanks'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        PaywallRejectionPromptCopy.thanksLine,
        textAlign: TextAlign.center,
        style: ArchiveMobileTypography.body(
          context,
        ).copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _questionBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          PaywallRejectionPromptCopy.title,
          style: ArchiveMobileTypography.responsiveSectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          PaywallRejectionPromptCopy.subtitle,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final reason in PaywallRejectionReason.values) ...[
          OutlinedButton(
            key: Key('paywall_rejection_${reason.id}'),
            onPressed: () => _selectReason(reason),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(reason.label, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextButton(
          key: const Key('paywall_rejection_skip'),
          onPressed: _skip,
          child: const Text(PaywallRejectionPromptCopy.skipLabel),
        ),
      ],
    );
  }
}
