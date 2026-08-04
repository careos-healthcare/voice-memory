import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared navigation for archive signal surfaces.
abstract class SignalArchiveNavigation {
  SignalArchiveNavigation._();

  static void openSignalDetail(BuildContext context) {
    context.push('/signal-detail');
  }

  static void openEvidenceTrail(BuildContext context) {
    context.push('/signal-evidence');
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
