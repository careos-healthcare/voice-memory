import 'dart:async';

import 'package:archiveme_mobile/features/monetization/output_format_gate.dart';
import 'package:archiveme_mobile/features/monetization/paywall_milestone_coordinator.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:flutter/material.dart';

/// Opens the upgrade sheet when a streak or archive milestone is completed.
class PaywallMilestoneHost extends StatefulWidget {
  const PaywallMilestoneHost({required this.child, super.key});

  final Widget child;

  @override
  State<PaywallMilestoneHost> createState() => _PaywallMilestoneHostState();
}

class _PaywallMilestoneHostState extends State<PaywallMilestoneHost> {
  var _presenting = false;

  @override
  void initState() {
    super.initState();
    PaywallMilestoneCoordinator.instance.addListener(_onWin);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onWin();
    });
  }

  @override
  void dispose() {
    PaywallMilestoneCoordinator.instance.removeListener(_onWin);
    super.dispose();
  }

  void _onWin() {
    if (_presenting || !mounted) return;
    if (PremiumAccess.current.isActive) {
      PaywallMilestoneCoordinator.instance.claimPending();
      return;
    }
    final win = PaywallMilestoneCoordinator.instance.claimPending();
    if (win == null) return;
    _presenting = true;
    unawaited(_present());
  }

  Future<void> _present() async {
    try {
      if (!mounted) return;
      await OutputFormatGate.presentPaywall(context);
    } finally {
      _presenting = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
