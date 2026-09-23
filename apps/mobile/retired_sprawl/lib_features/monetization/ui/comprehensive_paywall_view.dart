import 'package:archiveme_mobile/features/monetization/ui/continuity_paywall_section.dart';
import 'package:flutter/material.dart';

/// Continuity paywall for Watch sync, encrypted relay, and web handoff.
class ComprehensivePaywallView extends StatelessWidget {
  const ComprehensivePaywallView({super.key, this.onWebHandoff});

  final VoidCallback? onWebHandoff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '100% Offline & Privacy-First',
                    key: const Key('paywall_headline'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cloud recorders upload your voice to keep working. Capture and encrypted storage stay on this device, with no subscription.',
                    key: const Key('paywall_privacy_contrast'),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ContinuityPaywallSection(onWebHandoff: onWebHandoff),
            ),
          ],
        ),
      ),
    );
  }
}
