import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/memory/archive_evidence_type.dart';
import 'package:archiveme_mobile/features/memory/curated_memory_marker.dart';
import 'package:archiveme_mobile/features/memory/curated_memory_preservation_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_frame.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/fact_ledger/save_as_fact_button.dart';
import 'package:archiveme_mobile/widgets/memory/memory_surfacing_editor.dart';
import 'package:archiveme_mobile/widgets/memory/original_evidence_block.dart';
import 'package:archiveme_mobile/widgets/memory/preserve_original_control.dart';
import 'package:archiveme_mobile/widgets/memory/sensitive_surfacing_notice.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// All consumer copy for the evidence inspect sheet — compile-time
/// constants so tests can sweep them and no private content can leak in.
abstract class MemoryEvidenceInspectCopy {
  MemoryEvidenceInspectCopy._();

  static const String actionLabel = 'Show evidence';
  static const String sheetTitle = 'Evidence behind this card';
  static const String confirmedMarker = 'You confirmed this';
  static const String keepConnectedLabel = 'Keep connected';
  static const String keepConnectedDone =
      'Marked as connected. ArchiveMe will treat this as user-confirmed '
      'evidence.';
  static const String notRelatedLabel = 'Not related';
  static const String notRelatedDone =
      'Thanks — ArchiveMe will treat this as separate.';
  static const String futureFreshLabel = 'Treat future entries as new';
  static const String futureFreshDone =
      'Future entries here start as new. You can keep a connection later '
      'if it fits.';
  static const String emptyLine = 'No evidence items to show for this card.';
  static const String changeSurfacingLabel =
      MemorySurfacingCopy.changeSurfacingLabel;
  static const String footer = 'Entries stay in your archive unchanged.';
}

/// "Show evidence" — the privacy-safe evidence list behind a memory
/// card, plus lightweight per-card connection controls.
///
/// Each row shows safe metadata only: relative time bucket, evidence
/// type, and whether the user confirmed it; the header carries the
/// authority label. No note text, snippet, date, or entry id renders
/// here, and nothing on this sheet deletes or alters entries.
class MemoryEvidenceInspectSheet extends StatefulWidget {
  const MemoryEvidenceInspectSheet({required this.cardType, super.key});

  final MemoryCardType cardType;

  static Future<void> show(BuildContext context, MemoryCardType cardType) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryShowEvidenceOpened,
      cardType: cardType.id,
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MemoryEvidenceInspectSheet(cardType: cardType),
    );
  }

  @override
  State<MemoryEvidenceInspectSheet> createState() =>
      _MemoryEvidenceInspectSheetState();
}

class _MemoryEvidenceInspectSheetState
    extends State<MemoryEvidenceInspectSheet> {
  String? _doneLine;
  JournalEntry? _sourceEntry;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSourceEntry());
  }

  Future<void> _loadSourceEntry() async {
    final candidates = MemoryAuthorityFrameLog.candidatesFor(widget.cardType);
    if (candidates.isEmpty || !AppServices.isInitialized) return;
    final entry = await AppServices.instance.journalStore.getById(
      candidates.first.entryId,
    );
    if (!mounted) return;
    setState(() => _sourceEntry = entry);
  }

  void _keepConnected() {
    MemoryConnectionRules.keepConnected(widget.cardType);
    setState(() => _doneLine = MemoryEvidenceInspectCopy.keepConnectedDone);
  }

  void _notRelated() {
    MemoryControlStore.markNotRelated(widget.cardType);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryMarkedNotRelated,
      cardType: widget.cardType.id,
    );
    setState(() => _doneLine = MemoryEvidenceInspectCopy.notRelatedDone);
  }

  void _futureFresh() {
    MemoryConnectionRules.treatFutureAsNew(widget.cardType);
    setState(() => _doneLine = MemoryEvidenceInspectCopy.futureFreshDone);
  }

  void _openSourceEntry() {
    final entry = _sourceEntry;
    if (entry == null) return;
    final source = CuratedMemoryMarker.sourceFor(entry);
    CuratedMemoryPreservationPolicy.trackOriginalOpened(
      source: 'evidence_inspection',
      preservationSource: source,
    );
    unawaited(context.push('/entry/${entry.id}'));
  }

  bool get _showsOriginalEvidence {
    final items = MemoryAuthorityFrameLog.evidenceFor(widget.cardType);
    return items.any(
      (item) =>
          item.evidenceTypeLabel ==
              ArchiveEvidenceType.preservedOriginal.label ||
          item.evidenceTypeLabel == ArchiveEvidenceType.userMarkedDetail.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final frame = MemoryAuthorityFrameLog.frameFor(widget.cardType);
    final items = MemoryAuthorityFrameLog.evidenceFor(widget.cardType);

    return SafeArea(
      child: Padding(
        key: const Key('memory_evidence_inspect_sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MemoryEvidenceInspectCopy.sheetTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              CuratedMemoryCopy.summarySectionTitle,
              key: const Key('memory_evidence_summary_heading'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            if (frame != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _pill(context, frame.authorityState.label),
            ],
            const SizedBox(height: AppSpacing.xs),
            if (items.isEmpty)
              Text(
                MemoryEvidenceInspectCopy.emptyLine,
                key: const Key('memory_evidence_empty_line'),
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              )
            else
              ...items.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    _itemLine(entry.value),
                    key: Key('memory_evidence_item_${entry.key}'),
                    style: ArchiveMobileTypography.body(
                      context,
                    ).copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ),
            if (_showsOriginalEvidence) ...[
              const SizedBox(height: AppSpacing.sm),
              const OriginalEvidenceBlock(),
            ],
            if (_sourceEntry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                CuratedMemoryCopy.sourceEntrySectionTitle,
                key: const Key('memory_evidence_source_heading'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('memory_evidence_open_entry'),
                  onPressed: _openSourceEntry,
                  child: const Text(CuratedMemoryCopy.openEntryLabel),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SaveAsFactButton(
                entry: _sourceEntry!,
                store: FactLedgerStore.instance(),
                source: 'evidence_inspection',
              ),
              const SizedBox(height: AppSpacing.sm),
              PreserveOriginalEditor(
                entry: _sourceEntry!,
                onChanged: _loadSourceEntry,
              ),
              const SizedBox(height: AppSpacing.sm),
              MemorySurfacingEditor(
                entry: _sourceEntry!,
                cardType: widget.cardType,
                source: 'evidence_inspection',
                onChanged: () {
                  unawaited(_loadSourceEntry());
                  setState(() {});
                },
              ),
              if (MemorySurfacingMode.fromEntry(_sourceEntry!) ==
                  MemorySurfacingMode.sensitive)
                const SensitiveSurfacingNotice(),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (_doneLine != null)
              Text(
                _doneLine!,
                key: const Key('memory_evidence_done_line'),
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton(
                    key: const Key('memory_keep_connected_action'),
                    onPressed: _keepConnected,
                    child: const Text(MemoryEvidenceInspectCopy.keepConnectedLabel),
                  ),
                  OutlinedButton(
                    key: const Key('memory_inspect_not_related_action'),
                    onPressed: _notRelated,
                    child: const Text(MemoryEvidenceInspectCopy.notRelatedLabel),
                  ),
                  OutlinedButton(
                    key: const Key('memory_future_fresh_action'),
                    onPressed: _futureFresh,
                    child: const Text(MemoryEvidenceInspectCopy.futureFreshLabel),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MemoryEvidenceInspectCopy.footer,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _itemLine(MemoryEvidenceInspectItem item) {
    final parts = [
      item.timeBucketLabel,
      item.evidenceTypeLabel,
      if (item.userConfirmed) MemoryEvidenceInspectCopy.confirmedMarker,
    ];
    return parts.join(' · ');
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}