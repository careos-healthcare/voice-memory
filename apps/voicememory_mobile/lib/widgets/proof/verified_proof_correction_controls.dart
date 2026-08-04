import 'package:flutter/material.dart';

import '../../features/proof_admission/archive_correction.dart';
import '../../features/proof_admission/archive_correction_store.dart';
import '../../features/proof_admission/proof_admission_models.dart';

class VerifiedProofCorrectionControls extends StatefulWidget {
  const VerifiedProofCorrectionControls({
    super.key,
    required this.proof,
    required this.sourceSurface,
  });

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

  Future<void> _record(ArchiveCorrectionChoice choice) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ArchiveCorrectionStore.instance.recordForProof(
      proof: widget.proof,
      choice: choice,
      sourceSurface: widget.sourceSurface,
    );
    if (!mounted) return;
    setState(() {
      _saved = choice;
      _saving = false;
    });
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
            'Was this right?',
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
                  onPressed: _saving ? null : () => _record(choice),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(_label(choice)),
                ),
            ],
          ),
          if (_saved != null)
            Text(
              'Saved privately',
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
