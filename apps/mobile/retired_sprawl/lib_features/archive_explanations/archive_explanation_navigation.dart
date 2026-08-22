import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_analytics.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_question/archive_question_engine.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_tracker_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Route extras for [ArchiveExplanationScreen].
class ArchiveExplanationRouteArgs {
  const ArchiveExplanationRouteArgs({
    required this.ref,
    this.askPrompt,
    this.askCitedEntryIds = const [],
  });

  final ArchiveInsightRef ref;
  final String? askPrompt;
  final List<String> askCitedEntryIds;
}

/// Opens `/archive-explanation/:id` with optional ask-archive context.
void openArchiveExplanation(
  BuildContext context, {
  required ArchiveInsightRef ref,
  String? askPrompt,
  List<String>? askCitedEntryIds,
}) {
  ArchiveExplanationAnalytics.whyOpened(insightKind: ref.kind.name);
  unawaited(context.push(
    '/archive-explanation/${Uri.encodeComponent(ref.id)}',
    extra: ArchiveExplanationRouteArgs(
      ref: ref,
      askPrompt: askPrompt,
      askCitedEntryIds: askCitedEntryIds ?? const [],
    ),
  ));
}

String decodeArchiveExplanationRouteId(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  return Uri.decodeComponent(raw);
}

/// Maps archive home question chips to explanation routes.
ArchiveInsightRef insightRefForArchiveQuestion(ArchiveQuestionId id) {
  if (id == ArchiveQuestionId.why) return ArchiveInsightRef.belief();
  final label = ArchiveQuestionEngine.buttonLabels[id] ?? id.name;
  return ArchiveInsightRef.askArchive(label);
}

/// Resolves a top-themes display label to a canonical theme id.
String? themeKeyForDisplayName(String displayName) {
  final normalized = displayName.trim().toLowerCase();
  for (final entry in ThemeTrackerService.displayNames.entries) {
    if (entry.value.toLowerCase() == normalized) return entry.key;
    if (entry.key.toLowerCase() == normalized) return entry.key;
  }
  return null;
}