import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Navigation helpers for signal journey surfaces.
abstract class SignalJourneyNavigation {
  SignalJourneyNavigation._();

  static void openJourneyDetail(BuildContext context) {
    unawaited(context.push('/signal-journey'));
  }

  static void openPatterns(BuildContext context) {
    context.go('/archive-belief');
  }

  static void recordNextEvidence(BuildContext context, {String? prompt}) {
    final trimmed = prompt?.trim() ?? '';
    if (trimmed.isEmpty) {
      context.go('/record');
      return;
    }
    final encoded = Uri.encodeComponent(trimmed);
    context.go('/record?prompt=$encoded&autostart=1');
  }
}