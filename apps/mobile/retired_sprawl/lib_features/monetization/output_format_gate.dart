import 'dart:async';

import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/comprehensive_paywall_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Formats a free account can open without a purchase.
enum FreeOutputFormat { transcription, playback }

/// Formats that require an active `pro` or `archive_loop_pro` entitlement.
enum PremiumOutputFormat { emailDraft, professionalTemplate, coachingInsights }

/// Decides whether an output format runs or opens the continuity paywall.
abstract final class OutputFormatGate {
  OutputFormatGate._();

  static bool isFree(FreeOutputFormat format) {
    switch (format) {
      case FreeOutputFormat.transcription:
      case FreeOutputFormat.playback:
        return true;
    }
  }

  static bool allows(
    PremiumOutputFormat format,
    PremiumEntitlement entitlement,
  ) {
    switch (format) {
      case PremiumOutputFormat.emailDraft:
      case PremiumOutputFormat.professionalTemplate:
      case PremiumOutputFormat.coachingInsights:
        return entitlement.isActive;
    }
  }

  static PremiumEntitlement entitlementOf(BuildContext context) {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(premiumEntitlementProvider);
    } on Object {
      return PremiumAccess.current;
    }
  }

  /// Runs [onAllowed] for an active entitlement.
  ///
  /// A free account stays on the current screen. The upgrade sheet opens
  /// later, when a streak or archive milestone is completed.
  static Future<bool> intercept(
    BuildContext context, {
    required PremiumOutputFormat format,
    VoidCallback? onAllowed,
  }) async {
    if (allows(format, entitlementOf(context))) {
      onAllowed?.call();
      return true;
    }
    return false;
  }

  static Future<void> presentPaywall(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return UncontrolledProviderScope(
          container: container,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.92,
            child: const ComprehensivePaywallView(),
          ),
        );
      },
    );
  }
}

/// Raw transcript and playback stay open. Premium formats open the paywall.
class OutputFormatSurface extends ConsumerWidget {
  const OutputFormatSurface({
    required this.transcript,
    super.key,
    this.onPlay,
    this.onEmailDraft,
    this.onProfessionalTemplate,
    this.onCoachingInsights,
  });

  final String transcript;
  final VoidCallback? onPlay;
  final VoidCallback? onEmailDraft;
  final VoidCallback? onProfessionalTemplate;
  final VoidCallback? onCoachingInsights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(transcript, key: const Key('output_gate_transcript')),
        TextButton(
          key: const Key('output_gate_play'),
          onPressed: onPlay,
          child: const Text('Play'),
        ),
        TextButton(
          key: const Key('output_gate_email'),
          onPressed: () {
            unawaited(
              OutputFormatGate.intercept(
                context,
                format: PremiumOutputFormat.emailDraft,
                onAllowed: onEmailDraft,
              ),
            );
          },
          child: const Text('Customized email drafting'),
        ),
        TextButton(
          key: const Key('output_gate_template'),
          onPressed: () {
            unawaited(
              OutputFormatGate.intercept(
                context,
                format: PremiumOutputFormat.professionalTemplate,
                onAllowed: onProfessionalTemplate,
              ),
            );
          },
          child: const Text('Professional email and blog templates'),
        ),
        TextButton(
          key: const Key('output_gate_coaching'),
          onPressed: () {
            unawaited(
              OutputFormatGate.intercept(
                context,
                format: PremiumOutputFormat.coachingInsights,
                onAllowed: onCoachingInsights,
              ),
            );
          },
          child: const Text('Deep AI coaching insights'),
        ),
      ],
    );
  }
}
