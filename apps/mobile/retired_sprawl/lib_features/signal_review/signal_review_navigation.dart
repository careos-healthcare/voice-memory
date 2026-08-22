import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Navigation helpers for signal review surfaces.
abstract class SignalReviewNavigation {
  SignalReviewNavigation._();

  static void openFullReview(BuildContext context) {
    unawaited(context.push('/signal-review'));
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

  static void openPatterns(BuildContext context) {
    context.go('/archive-belief');
  }
}