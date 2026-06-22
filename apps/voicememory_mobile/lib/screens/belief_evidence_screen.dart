import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/pressure_retention/shareable_archive_proof_engine.dart';
import '../features/pressure_retention/shareable_archive_proof_model.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive/belief_evidence_trail_card.dart';
import '../widgets/consumer/consumer_screen_back_header.dart';
import '../widgets/pressure_retention/shareable_archive_proof_card.dart';

/// Proof trail for a belief update — saved words, not guesses.
class BeliefEvidenceScreen extends StatefulWidget {
  const BeliefEvidenceScreen({super.key, this.previewTrail});

  /// Test-only: skip async load and render this trail.
  @visibleForTesting
  final BeliefEvidenceTrail? previewTrail;

  @override
  State<BeliefEvidenceScreen> createState() => _BeliefEvidenceScreenState();
}

class _BeliefEvidenceScreenState extends State<BeliefEvidenceScreen> {
  BeliefEvidenceTrail? _trail;
  ShareableArchiveProof? _shareProof;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewTrail;
    if (preview != null) {
      _trail = preview;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _trail = BeliefEvidenceTrailEngine.build(entries: entries);
      _shareProof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: entries,
      );
      _loading = false;
    });
  }

  void _goToRecord() {
    context.go('/record');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Padding(
            padding: ArchiveMobileSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ConsumerScreenBackHeader(),
                const SizedBox(height: AppSpacing.lg),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );
    }

    final trail = _trail ?? BeliefEvidenceTrail.insufficient();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: ArchiveMobileSpacing.pagePadding,
            children: [
              const ConsumerScreenBackHeader(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                trail.title,
                key: const Key('belief_evidence_screen_title'),
                style: VoiceMemoryTypography.headlineStyle(),
              ),
              const SizedBox(height: AppSpacing.lg),
              BeliefEvidenceTrailCard(
                trail: trail,
                onAddAnother:
                    trail.hasEnoughEvidence ? _goToRecord : null,
              ),
              if (_shareProof?.hasProof == true) ...[
                const SizedBox(height: AppSpacing.lg),
                ShareableArchiveProofCard(proof: _shareProof!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
