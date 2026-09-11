import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/features/proof_admission/verified_proof_view_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/local_privacy_data_controls.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Live list of observations the archive was told to stop raising.
class StoppedObservationsSheet extends StatefulWidget {
  const StoppedObservationsSheet({required this.controls, super.key});

  final LocalPrivacyDataControls controls;

  static Future<void> show(
    BuildContext context, {
    required LocalPrivacyDataControls controls,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StoppedObservationsSheet(controls: controls),
    );
  }

  @override
  State<StoppedObservationsSheet> createState() =>
      _StoppedObservationsSheetState();
}

class _StoppedObservationsSheetState extends State<StoppedObservationsSheet> {
  static const _snippetMaxChars = 80;

  List<_StoppedObservationRow> _rows = const [];
  bool _loading = true;
  String? _undoingId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final corrections = await widget.controls.ignoredObservations();
    final byCreatedAt = List<ArchiveCorrection>.from(corrections)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final entriesById = await _loadEntries(byCreatedAt);
    if (!mounted) return;

    setState(() {
      _rows = [
        for (final correction in byCreatedAt)
          _StoppedObservationRow(
            correction: correction,
            snippets: _snippetsFor(correction, entriesById),
          ),
      ];
      _loading = false;
      _undoingId = null;
    });
  }

  Future<Map<String, JournalEntry>> _loadEntries(
    List<ArchiveCorrection> corrections,
  ) async {
    if (!AppServices.isInitialized) return const {};

    final refs = <String>{
      for (final correction in corrections) ...correction.affectedEvidenceRefs,
    };
    if (refs.isEmpty) return const {};

    final loaded = <String, JournalEntry>{};
    for (final id in refs) {
      final entry = await AppServices.instance.journalStore.getById(id);
      if (entry != null) loaded[id] = entry;
    }
    return loaded;
  }

  List<String> _snippetsFor(
    ArchiveCorrection correction,
    Map<String, JournalEntry> entriesById,
  ) {
    final snippets = <String>[];
    for (final id in correction.affectedEvidenceRefs) {
      final entry = entriesById[id];
      if (entry == null) continue;
      final snippet = _snippet(entry);
      if (snippet != null) snippets.add(snippet);
    }
    return snippets;
  }

  String? _snippet(JournalEntry entry) {
    final text = ComparableEvidenceText.userText(entry);
    if (text.isEmpty) return null;
    final firstLine = text.split(RegExp(r'\r?\n')).first.trim();
    if (firstLine.isEmpty) return null;
    if (firstLine.length <= _snippetMaxChars) return firstLine;
    return '${firstLine.substring(0, _snippetMaxChars).trimRight()}…';
  }

  Future<void> _undo(_StoppedObservationRow row) async {
    if (_undoingId != null) return;
    final confirmed = await _confirmUndo();
    if (!confirmed || !mounted) return;

    setState(() => _undoingId = row.correction.correctionId);
    try {
      final lifted = await widget.controls.stopIgnoring(row.correction);
      if (!mounted) return;
      if (lifted <= 0) {
        _showUndoFailed();
        setState(() => _undoingId = null);
        return;
      }
      await _reload();
    } on Object {
      if (!mounted) return;
      _showUndoFailed();
      setState(() => _undoingId = null);
    }
  }

  Future<bool> _confirmUndo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('stopped_observations_undo_confirm'),
        title: const Text(PrivacyTrustCopy.stoppedObservationsUndoTitle),
        content: const Text(PrivacyTrustCopy.stoppedObservationsUndoBody),
        actions: [
          TextButton(
            key: const Key('stopped_observations_undo_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(PrivacyTrustCopy.stoppedObservationsUndoCancel),
          ),
          TextButton(
            key: const Key('stopped_observations_undo_accept'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(PrivacyTrustCopy.stoppedObservationsUndoConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showUndoFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(PrivacyTrustCopy.stoppedObservationsUndoFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: SizedBox(
          key: Key('stopped_observations_loading'),
          height: 120,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('stopped_observations_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PrivacyTrustCopy.stoppedObservationsControl,
                key: const Key('stopped_observations_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_rows.isEmpty)
                Text(
                  PrivacyTrustCopy.stoppedObservationsEmpty,
                  key: const Key('stopped_observations_empty'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                )
              else
                for (final row in _rows) _buildRow(row),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(_StoppedObservationRow row) {
    final dateLabel = formatUserFacingDate(row.correction.createdAt);
    final subtitle = row.snippets.isEmpty
        ? PrivacyTrustCopy.stoppedObservationsFallback(dateLabel)
        : [dateLabel, ...row.snippets].join('\n');

    return ListTile(
      key: Key('stopped_observations_row_${row.correction.correctionId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        VerifiedProofViewModel.correctionLineFor(row.correction.choice),
        style: ArchiveMobileTypography.listTitle(context),
      ),
      subtitle: Text(
        subtitle,
        style: ArchiveMobileTypography.listSubtitle(context),
      ),
      trailing: row.correction.correctionId == _undoingId
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              key: Key(
                'stopped_observations_undo_${row.correction.correctionId}',
              ),
              onPressed: () => unawaited(_undo(row)),
              child: const Text(PrivacyTrustCopy.stoppedObservationsUndo),
            ),
    );
  }
}

class _StoppedObservationRow {
  const _StoppedObservationRow({
    required this.correction,
    required this.snippets,
  });

  final ArchiveCorrection correction;
  final List<String> snippets;
}
