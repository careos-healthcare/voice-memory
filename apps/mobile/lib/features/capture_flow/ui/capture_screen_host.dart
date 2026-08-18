import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_screen.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:flutter/material.dart';

/// Production capture entry — voice, typed, attach-to-voice, and post-save recovery.
class CaptureScreenHost extends StatelessWidget {
  const CaptureScreenHost({
    super.key,
    this.initialInputMode = CaptureInputMode.voice,
    this.attachToEntryId,
    this.initialTypedText,
    this.accountDependencies,
    this.navigationActivityController,
  });

  final CaptureInputMode initialInputMode;
  final String? attachToEntryId;
  final String? initialTypedText;
  final V1AccountDependencies? accountDependencies;
  final RecordNavigationActivityController? navigationActivityController;

  @override
  Widget build(BuildContext context) {
    return CaptureScreen(
      initialInputMode: initialInputMode,
      attachToEntryId: attachToEntryId,
      initialTypedText: initialTypedText,
      accountDependencies: accountDependencies,
      navigationActivityController: navigationActivityController,
    );
  }
}
