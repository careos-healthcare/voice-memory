import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/features/capture/providers/capture_module_providers.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_screen.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Production capture entry — voice, typed, attach-to-voice, and post-save recovery.
class CaptureScreenHost extends ConsumerWidget {
  const CaptureScreenHost({
    super.key,
    this.initialInputMode = CaptureInputMode.voice,
    this.attachToEntryId,
    this.initialTypedText,
    this.routineKindOverride,
    this.accountDependencies,
    this.navigationActivityController,
    this.routeState,
  });

  final CaptureInputMode initialInputMode;
  final String? attachToEntryId;
  final String? initialTypedText;
  final JournalRoutineKind? routineKindOverride;
  final V1AccountDependencies? accountDependencies;
  final RecordNavigationActivityController? navigationActivityController;
  final GoRouterState? routeState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = routeState?.uri.queryParameters ?? const {};
    final allowBackgroundRecording = params['background'] == '1';
    final adoptBackgroundCapture = allowBackgroundRecording &&
        (params['autostart'] == '1' || params['instant'] == '1');
    final backgroundCapture = ref.watch(backgroundCaptureServiceProvider);

    return CaptureScreen(
      initialInputMode: initialInputMode,
      attachToEntryId: attachToEntryId,
      initialTypedText: initialTypedText,
      routineKindOverride: routineKindOverride,
      accountDependencies: accountDependencies,
      navigationActivityController: navigationActivityController,
      allowBackgroundRecording: allowBackgroundRecording,
      adoptBackgroundCapture: adoptBackgroundCapture,
      stopBackgroundCapture: backgroundCapture?.stopBackgroundCapture,
    );
  }
}
