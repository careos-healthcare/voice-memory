import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/capture_pipeline_service.dart';
import 'guided_examples_copy.dart';

/// One ordinary example entry — display only until the user types their own words.
class GuidedExample {
  const GuidedExample({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;
}

/// Catalog of permissive first-use examples — never persisted as journal entries.
abstract final class GuidedExamplesCatalog {
  GuidedExamplesCatalog._();

  static const analyticsSource = 'guided_example_style';

  static const examples = [
    GuidedExample(
      id: 'agreed_before_checking',
      text: 'I agreed before checking if I had time.',
    ),
    GuidedExample(
      id: 'kept_thinking_message',
      text: 'I kept thinking about that message.',
    ),
    GuidedExample(
      id: 'nothing_much_calmer',
      text: 'Nothing much happened, but I felt calmer today.',
    ),
    GuidedExample(
      id: 'paused_before_replying',
      text: 'I paused before replying.',
    ),
    GuidedExample(
      id: 'pressure_answer_quickly',
      text: 'I felt pressure to answer quickly.',
    ),
  ];
}

/// When guided examples appear on Record / typed capture.
abstract final class GuidedExamplesGates {
  GuidedExamplesGates._();

  /// Hide after the user has a comparison seed — keeps returning Record clean.
  static const hideAtEntryCount = 2;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isPostSave,
  }) =>
      loaded &&
      isReady &&
      !isPostSave &&
      entryCount < hideAtEntryCount;
}

/// Opens typed capture with a style helper only — example text is never saved.
Future<CapturePipelineResult?> navigateToGuidedExampleStyle(
  BuildContext context, {
  required GuidedExample example,
  Future<void> Function(CapturePipelineResult result)? onSaved,
}) async {
  final result = await context.push<CapturePipelineResult>(
    '/quick-capture',
    extra: <String, Object?>{
      'helper': GuidedExamplesCopy.styleHelper(example.text),
      'captureModeId': GuidedExamplesCatalog.analyticsSource,
      'showGuidedExamples': true,
    },
  );
  if (result == null || !context.mounted) return null;
  if (onSaved != null) {
    await onSaved(result);
  }
  return result;
}
