import 'dart:async';

import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_navigation.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_builder.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:archiveme_mobile/features/first25/first25_user_metrics.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:archiveme_mobile/features/retention/retention_analytics.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/evidence_trail/evidence_trail_sheet.dart';
import 'package:flutter/material.dart';

/// User-facing affordance label for Evidence Trail V1.
const String kWhyAmISeeingThisLabel = 'Why am I seeing this?';

/// Opens the evidence bottom sheet when [payload] is available.
Future<void> showEvidenceTrailSheet(
  BuildContext context, {
  required EvidenceTrailPayload payload,
  required String surface,
  ArchiveInsightRef? ref,
  List<JournalEntry>? entries,
  ArchiveStateObjectV3? state,
}) async {
  RetentionAnalytics.evidenceOpened(context: surface);
  await First25UserMetrics.trackEvidenceOpened(surface: surface);
  unawaited(DelayedPaywallProofStore.markEvidenceTrailOpened());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => EvidenceTrailSheet(
      payload: payload,
      surface: surface,
      onOpenFullExplanation: ref != null && entries != null
          ? () {
              Navigator.of(ctx).pop();
              openArchiveExplanation(
                context,
                ref: ref,
                askCitedEntryIds: payload.sources
                    .map((s) => s.entryId)
                    .toList(),
              );
            }
          : null,
    ),
  );
}

/// Resolves journal + builds trail from an [ArchiveInsightRef].
Future<void> openEvidenceTrailForInsight(
  BuildContext context, {
  required ArchiveInsightRef ref,
  List<JournalEntry>? entries,
  ArchiveStateObjectV3? state,
  String surface = 'insight',
  String? askPrompt,
  List<String>? askCitedEntryIds,
}) async {
  final loaded = entries ?? await AppServices.instance.journal.loadAll();
  final resolvedState = state ?? buildArchiveStateObjectV3(entries: loaded);
  final payload = buildEvidenceTrailForInsight(
    ref: ref,
    entries: loaded,
    state: resolvedState,
    askPrompt: askPrompt,
    askCitedEntryIds: askCitedEntryIds,
  );
  if (payload == null || !context.mounted) return;
  await showEvidenceTrailSheet(
    context,
    payload: payload,
    surface: surface,
    ref: ref,
    entries: loaded,
    state: resolvedState,
  );
}