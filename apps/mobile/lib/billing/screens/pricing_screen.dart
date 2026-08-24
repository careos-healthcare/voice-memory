import 'package:archiveme_mobile/billing/screens/paywall_screen.dart';
import 'package:flutter/material.dart';

/// Legacy `/pricing` route — renders subscription UI directly (no redirect spinner).
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaywallScreen();
  }
}