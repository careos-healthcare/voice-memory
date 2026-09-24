import 'package:archiveme_mobile/features/monetization/ui/comprehensive_paywall_view.dart';
import 'package:flutter/material.dart';

/// Premium screen for cross-platform continuity and advanced AI.
class PaywallView extends StatelessWidget {
  const PaywallView({super.key, this.onWebHandoff});

  final VoidCallback? onWebHandoff;

  @override
  Widget build(BuildContext context) {
    return ComprehensivePaywallView(onWebHandoff: onWebHandoff);
  }
}
