import 'package:flutter/material.dart';

/// One Pro benefit row in the staggered paywall feature list.
class ProPaywallFeatureItem {
  const ProPaywallFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}