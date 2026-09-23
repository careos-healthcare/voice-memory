import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/paywall_milestone_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps raw transcript playback open and gates premium writing tools.
class AIFeatureGate extends ConsumerWidget {
  const AIFeatureGate({
    required this.transcript,
    super.key,
    this.onPlay,
    this.onEmailDraft,
    this.onAdvancedCoaching,
  });

  final String transcript;
  final VoidCallback? onPlay;
  final VoidCallback? onEmailDraft;
  final VoidCallback? onAdvancedCoaching;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumEntitlementProvider).isActive;
    return PaywallMilestoneHost(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(transcript, key: const Key('ai_gate_transcript')),
          TextButton(
            key: const Key('ai_gate_play'),
            onPressed: onPlay,
            child: const Text('Play'),
          ),
          TextButton(
            key: const Key('ai_gate_email'),
            onPressed: () => _guard(context, premium, onEmailDraft),
            child: const Text('Customized email drafting'),
          ),
          TextButton(
            key: const Key('ai_gate_coaching'),
            onPressed: () => _guard(context, premium, onAdvancedCoaching),
            child: const Text('Advanced AI coaching'),
          ),
        ],
      ),
    );
  }

  void _guard(BuildContext context, bool premium, VoidCallback? action) {
    if (!premium) return;
    action?.call();
  }
}
