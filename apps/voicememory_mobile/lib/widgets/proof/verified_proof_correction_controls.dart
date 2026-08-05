import 'package:flutter/material.dart';

import '../../features/proof_admission/archive_correction.dart';
import '../../features/proof_admission/archive_correction_store.dart';
import '../../features/proof_admission/proof_admission_models.dart';
import '../../features/proof_admission/verified_proof_view_model.dart';

class VerifiedProofCorrectionControls extends StatefulWidget {
  const VerifiedProofCorrectionControls({
    super.key,
    required this.proof,
    required this.sourceSurface,
  });

  static const String prompt = 'Was this right?';
  static const String savedConfirmation = 'Saved privately';

  static const String ignoreTitle = 'Stop seeing this?';
  static const String ignoreBody =
      'This wording and close versions of it will stop appearing in this '
      'archive. Your moments are kept, and you can undo this in privacy '
      'settings.';
  static const String ignoreConfirm = 'Stop seeing this';
  static const String ignoreCancel = 'Cancel';

  static const String wrongEvidenceTitle = 'Which part is wrong?';
  static const String wrongEvidenceConfirm = 'Save';

  final VerifiedProof proof;
  final String sourceSurface;

  @override
  State<VerifiedProofCorrectionControls> createState() =>
      _VerifiedProofCorrectionControlsState();
}

class _VerifiedProofCorrectionControlsState
    extends State<VerifiedProofCorrectionControls> {
  ArchiveCorrectionChoice? _saved;
  bool _saving = false;

  Future<void> _select(ArchiveCorrectionChoice choice) async {
    if (_saving) return;

    // Ignore forever creates durable archive-wide suppression, so it is the one
    // choice that cannot be committed by a single tap.
    if (choice == ArchiveCorrectionChoice.ignoreForever) {
      final confirmed = await _confirmIgnore();
      if (!confirmed) return;
      await _record(choice);
      return;
    }

    if (choice == ArchiveCorrectionChoice.wrongEvidence) {
      final disputed = await _pickDisputedEvidence();
      if (disputed == null) return;
      await _record(choice, disputedEvidenceRefs: disputed);
      return;
    }

    await _record(choice);
  }

  Future<void> _record(
    ArchiveCorrectionChoice choice, {
    List<String> disputedEvidenceRefs = const [],
  }) async {
    setState(() => _saving = true);
    await ArchiveCorrectionStore.instance.recordForProof(
      proof: widget.proof,
      choice: choice,
      sourceSurface: widget.sourceSurface,
      disputedEvidenceRefs: disputedEvidenceRefs,
    );
    if (!mounted) return;
    setState(() {
      _saved = choice;
      _saving = false;
    });
  }

  Future<bool> _confirmIgnore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('proof_correction_ignore_confirm'),
        title: const Text(VerifiedProofCorrectionControls.ignoreTitle),
        content: const Text(VerifiedProofCorrectionControls.ignoreBody),
        actions: [
          TextButton(
            key: const Key('proof_correction_ignore_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(VerifiedProofCorrectionControls.ignoreCancel),
          ),
          TextButton(
            key: const Key('proof_correction_ignore_accept'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(VerifiedProofCorrectionControls.ignoreConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Returns the disputed source ids, or null when the user backed out. An
  /// empty list means the whole citation set was disputed.
  Future<List<String>?> _pickDisputedEvidence() async {
    final evidence = VerifiedProofViewModel.fromVerifiedProof(
      widget.proof,
    ).supportingEvidence;
    if (evidence.isEmpty) return const [];
    final selected = <String>{};

    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          key: const Key('proof_correction_evidence_picker'),
          title: const Text(VerifiedProofCorrectionControls.wrongEvidenceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in evidence)
                CheckboxListTile(
                  key: Key('proof_correction_evidence_${item.sourceEntryId}'),
                  value: selected.contains(item.sourceEntryId),
                  title: Text('“${item.quote}”'),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selected.add(item.sourceEntryId);
                    } else {
                      selected.remove(item.sourceEntryId);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('proof_correction_evidence_cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(VerifiedProofCorrectionControls.ignoreCancel),
            ),
            TextButton(
              key: const Key('proof_correction_evidence_save'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(selected.toList()..sort()),
              child: const Text(
                VerifiedProofCorrectionControls.wrongEvidenceConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Correct this evidence-based observation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            VerifiedProofCorrectionControls.prompt,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final choice in ArchiveCorrectionChoice.values)
                TextButton(
                  key: Key('proof_correction_${choice.name}'),
                  onPressed: _saving ? null : () => _select(choice),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(_label(choice)),
                ),
            ],
          ),
          if (_saved != null)
            Text(
              VerifiedProofCorrectionControls.savedConfirmation,
              key: const Key('proof_correction_saved'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  String _label(ArchiveCorrectionChoice choice) => switch (choice) {
    ArchiveCorrectionChoice.exactlyRight => 'Exactly right',
    ArchiveCorrectionChoice.partlyRight => 'Partly right',
    ArchiveCorrectionChoice.wrong => 'Wrong',
    ArchiveCorrectionChoice.wrongWording => 'Wrong wording',
    ArchiveCorrectionChoice.wrongEvidence => 'Wrong evidence',
    ArchiveCorrectionChoice.ignoreForever => 'Ignore forever',
  };
}
