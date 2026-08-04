import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/bulk_actions/bulk_archive_action.dart';
import '../../features/action_items/action_item_store.dart';
import '../../features/action_items/archive_action_item.dart';
import '../../features/fact_ledger/archive_fact.dart';
import '../../features/fact_ledger/fact_ledger_store.dart';
import '../../features/export/archive_export_format.dart';
import '../../features/export/selected_archive_export.dart';
import '../../features/pressure_retention/pressure_check_in_record.dart';
import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_spacing.dart';

/// Export sheet for explicitly selected entries — and only those.
///
/// The export file may contain the selected entry text because the
/// user chose to export it. Analytics carries the format id and a
/// coarse selection bucket only — never the exported text.
Future<bool?> showExportSelectedSheet(
  BuildContext context, {
  required List<JournalEntry> selectedEntries,
  List<PressureCheckInRecord> records = const [],
  String source = 'archive_search',
  Future<void> Function(String contents, String fileName)? onShare,
  VoidCallback? onExported,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ExportSelectedSheet(
      selectedEntries: selectedEntries,
      records: records,
      source: source,
      onShare: onShare,
      onExported: onExported,
    ),
  );
}

class ExportSelectedSheet extends StatefulWidget {
  const ExportSelectedSheet({
    super.key,
    required this.selectedEntries,
    this.records = const [],
    this.source = 'archive_search',
    this.onShare,
    this.onExported,
  });

  final List<JournalEntry> selectedEntries;
  final List<PressureCheckInRecord> records;

  /// Stable analytics source id only.
  final String source;

  /// Receives the export contents and safe filename. Injectable for
  /// tests; defaults to a temp file plus the system share sheet.
  final Future<void> Function(String contents, String fileName)? onShare;

  /// Called once the export has been produced and handed off.
  final VoidCallback? onExported;

  @override
  State<ExportSelectedSheet> createState() => _ExportSelectedSheetState();
}

class _ExportSelectedSheetState extends State<ExportSelectedSheet> {
  var _busy = false;
  var _complete = false;

  Future<void> _export(ArchiveExportFormat format) async {
    if (_busy) return;
    setState(() => _busy = true);
    final bucket = ActivationFunnelAnalytics.resultCountBucket(
      widget.selectedEntries.length,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveExportSelectedStarted,
      format: format.id,
      source: widget.source,
      selectionCountBucket: bucket,
    );
    try {
      final now = DateTime.now();
      var actionItems = const <ArchiveActionItem>[];
      var facts = const <ArchiveFact>[];
      try {
        actionItems = await ActionItemStore.instance().loadAll();
        facts = await FactLedgerStore.instance().loadAll();
      } catch (_) {
        // Optional markers when stores are unavailable.
      }
      final markdown = const SelectedArchiveExport().buildMarkdown(
        selectedEntries: widget.selectedEntries,
        records: widget.records,
        actionItems: actionItems,
        facts: facts,
        now: now,
      );
      final fileName = SelectedArchiveExport.fileName(now, format: format);
      final share = widget.onShare ?? _systemShare;
      await share(markdown, fileName);
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.archiveExportSelectedCompleted,
        format: format.id,
        source: widget.source,
        selectionCountBucket: bucket,
      );
      widget.onExported?.call();
      if (mounted) setState(() => _complete = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(SelectedArchiveExport.failureMessage),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _systemShare(String contents, String fileName) async {
    // App-private temporary files need no READ_MEDIA_* permission on Android
    // 13+, while FileProvider grants the chosen share target temporary access.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contents, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: fileName);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BulkActionsCopy.exportSelected,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              BulkActionsCopy.selectedCount(widget.selectedEntries.length),
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_complete)
              Text(
                BulkActionsCopy.exportComplete,
                key: const Key('export_complete_receipt'),
                style: ArchiveMobileTypography.cardLabel(context),
              )
            else ...[
              Text(
                BulkActionsCopy.chooseFormat,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final format in ArchiveExportFormat.supported)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: Key('export_format_${format.id}'),
                      onPressed: _busy ? null : () => _export(format),
                      child: Text(
                        format == ArchiveExportFormat.markdown
                            ? BulkActionsCopy.exportMarkdown
                            : BulkActionsCopy.exportPdf,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
