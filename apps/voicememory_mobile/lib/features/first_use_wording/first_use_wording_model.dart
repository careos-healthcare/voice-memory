import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/capture_pipeline_service.dart';
import 'first_use_wording_analytics.dart';
import 'first_use_wording_copy.dart';

/// One opening prompt — display only until the user writes their own words.
class FirstUseWordingPrompt {
  const FirstUseWordingPrompt({
    required this.id,
    required this.opening,
  });

  final String id;
  final String opening;
}

/// Catalog of first-use opening prompts — never persisted as journal entries.
abstract final class FirstUseWordingCatalog {
  FirstUseWordingCatalog._();

  static const captureModeId = 'first_use_wording_helper';

  static const prompts = [
    FirstUseWordingPrompt(id: 'today_i_noticed', opening: 'Today I noticed…'),
    FirstUseWordingPrompt(
      id: 'kept_thinking_about',
      opening: 'I kept thinking about…',
    ),
    FirstUseWordingPrompt(
      id: 'felt_pressure_when',
      opening: 'I felt pressure when…',
    ),
    FirstUseWordingPrompt(
      id: 'nearly_did_usual',
      opening: 'I nearly did the usual thing…',
    ),
    FirstUseWordingPrompt(
      id: 'did_something_different',
      opening: 'I did something different…',
    ),
  ];
}

/// When the first-use wording helper appears on Record / typed capture.
abstract final class FirstUseWordingGates {
  FirstUseWordingGates._();

  /// Hide after the user has a comparison seed — keeps returning Record clean.
  static const hideAtEntryCount = 2;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isPostSave,
    bool isRecordCluttered = false,
  }) =>
      loaded &&
      isReady &&
      !isPostSave &&
      entryCount < hideAtEntryCount &&
      (entryCount == 0 || !isRecordCluttered);
}

/// Opens typed capture with an opening placeholder only — never saved.
Future<CapturePipelineResult?> navigateToFirstUseWordingOpening(
  BuildContext context, {
  required FirstUseWordingPrompt prompt,
  required String source,
  Future<void> Function(CapturePipelineResult result)? onSaved,
}) async {
  FirstUseWordingAnalytics.selected(
    source: source,
    promptType: prompt.id,
  );
  final result = await context.push<CapturePipelineResult>(
    '/quick-capture',
    extra: <String, Object?>{
      'prompt': prompt.opening,
      'captureModeId': FirstUseWordingCatalog.captureModeId,
      'showFirstUseWordingHelper': true,
    },
  );
  if (result == null || !context.mounted) return null;
  if (onSaved != null) {
    await onSaved(result);
  }
  return result;
}
