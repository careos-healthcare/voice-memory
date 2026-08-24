import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart'
    show CaptureInputMode;
import 'package:archiveme_mobile/features/capture_flow/ui/capture_screen_host.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Production host for `/record` (voice) and `/quick-capture` (typed).
///
/// Live `features/capture/` has audio/VAD services and legacy typed UI, but no
/// standalone voice recorder. [CaptureScreenHost] is the only working
/// voice+typed surface, so this file delegates to that one widget.
///
/// Imports Host + [CaptureInputMode] only — not adapters, controllers, or
/// panels under `capture_flow`.
class LiveCaptureHost extends StatelessWidget {
  const LiveCaptureHost({
    super.key,
    this.typed = false,
    this.attachToEntryId,
    this.initialTypedText,
    this.routineKindOverride,
    this.accountDependencies,
    this.navigationActivityController,
    this.routeState,
  });

  /// Typed mode for `/quick-capture`. Voice is the `/record` default.
  final bool typed;
  final String? attachToEntryId;
  final String? initialTypedText;
  final JournalRoutineKind? routineKindOverride;
  final V1AccountDependencies? accountDependencies;
  final RecordNavigationActivityController? navigationActivityController;
  final GoRouterState? routeState;

  @override
  Widget build(BuildContext context) {
    return CaptureScreenHost(
      initialInputMode: typed ? CaptureInputMode.typed : CaptureInputMode.voice,
      attachToEntryId: attachToEntryId,
      initialTypedText: initialTypedText,
      routineKindOverride: routineKindOverride,
      accountDependencies: accountDependencies,
      navigationActivityController: navigationActivityController,
      routeState: routeState,
    );
  }
}
