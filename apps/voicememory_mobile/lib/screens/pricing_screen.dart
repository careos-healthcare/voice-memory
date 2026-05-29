import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/entitlement.dart';
import '../services/app_services.dart';
import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  PremiumEntitlements? _entitlements;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await AppServices.instance.billing.loadEntitlements();
    setState(() => _entitlements = e);
  }

  @override
  Widget build(BuildContext context) {
    final e = _entitlements ?? PremiumEntitlements.free();
    return ScaffoldShell(
      title: 'Pricing',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PlaceholderPanel(
            title: 'Pro (placeholder)',
            body: AppConfig.nativeBillingImplemented
                ? 'Native billing'
                : 'Stripe Checkout lives on web. No StoreKit / Play Billing.',
            status: 'Tier: ${e.tier.name} · billingConnected: ${e.billingConnected}',
          ),
          const SizedBox(height: 16),
          const Text('Free tier: record and recent archive (web truth).'),
          const SizedBox(height: 8),
          Text('Entitlements: ${e.entitlementIds.isEmpty ? "none" : e.entitlementIds.join(", ")}'),
        ],
      ),
    );
  }
}
