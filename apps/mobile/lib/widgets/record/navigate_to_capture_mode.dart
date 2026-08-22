import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_model.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens typed capture for a capture mode — prompt/helper only, never prefilled.
Future<CapturePipelineResult?> navigateToCaptureMode(
  BuildContext context, {
  required RecordCaptureMode mode,
  Future<void> Function(CapturePipelineResult result)? onSaved,
}) async {
  final result = await context.push<CapturePipelineResult>(
    '/quick-capture',
    extra: <String, Object?>{
      'prompt': mode.prompt,
      'helper': mode.helper,
      'captureModeId': mode.analyticsId,
      'allowQuietDaySave': mode.isQuietDay,
    },
  );
  if (result == null || !context.mounted) return null;
  if (onSaved != null) {
    await onSaved(result);
  }
  return result;
}