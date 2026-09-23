import 'dart:async';

import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/upgrade_tier_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Continuity benefits and the purchase actions for the premium sheet.
class ContinuityPaywallSection extends ConsumerWidget {
  const ContinuityPaywallSection({super.key, this.onWebHandoff});

  static final Uri webUri = Uri.parse('https://archiveme.app');

  final VoidCallback? onWebHandoff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(premiumEntitlementProvider);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: const [
              UpgradeTierIndicators(),
              _ContinuityPoint(
                id: 'paywall_benefit_watch',
                title: 'Unlimited Watch Sync',
                body:
                    'Free keeps one Watch recording. Unlimited Watch Sync removes that cap and unlocks unlimited Apple Watch synchronization for standalone Watch recordings.',
              ),
              _ContinuityPoint(
                id: 'paywall_benefit_relay',
                title: 'E2EE Cloud Relay',
                body:
                    'E2EE cloud relay backup stores an encrypted copy in an encrypted cloud bucket for a secondary phone or tablet when that device is offline.',
              ),
              _ContinuityPoint(
                id: 'paywall_benefit_web',
                title: 'Web & Desktop Dashboard Handoff',
                body:
                    'Web and desktop dashboard handoff opens the same note at https://archiveme.app.',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entitlement.isActive)
                const Text(
                  'Premium is active',
                  key: Key('paywall_active'),
                )
              else
                FilledButton(
                  key: const Key('paywall_purchase'),
                  onPressed: () {
                    unawaited(
                      ref.read(premiumEntitlementProvider.notifier).purchase(),
                    );
                  },
                  child: const Text('Start Premium'),
                ),
              TextButton(
                key: const Key('paywall_restore'),
                onPressed: () {
                  unawaited(
                    ref.read(premiumEntitlementProvider.notifier).restore(),
                  );
                },
                child: const Text('Restore purchases'),
              ),
              if (entitlement.canHandoffToWeb)
                TextButton(
                  key: const Key('paywall_web_handoff'),
                  onPressed: () {
                    final open = onWebHandoff;
                    if (open != null) {
                      open();
                      return;
                    }
                    unawaited(
                      launchUrl(
                        webUri,
                        mode: LaunchMode.externalApplication,
                      ),
                    );
                  },
                  child: const Text('Open on the web'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContinuityPoint extends StatelessWidget {
  const _ContinuityPoint({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        key: Key(id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
