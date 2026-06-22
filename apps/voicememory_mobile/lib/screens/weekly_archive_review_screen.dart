import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/weekly_archive_review.dart';
import '../features/pressure_retention/shareable_archive_proof_engine.dart';
import '../features/pressure_retention/shareable_archive_proof_model.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive/weekly_archive_review_card.dart';
import '../widgets/consumer/consumer_screen_back_header.dart';
import '../widgets/pressure_retention/shareable_archive_proof_card.dart';

/// Full weekly archive review — strongest thread, change, evidence, uncertainty.
class WeeklyArchiveReviewScreen extends StatefulWidget {
  const WeeklyArchiveReviewScreen({super.key, this.previewReview});

  /// Test-only: skip async load and render this review.
  @visibleForTesting
  final WeeklyArchiveReview? previewReview;

  @override
  State<WeeklyArchiveReviewScreen> createState() =>
      _WeeklyArchiveReviewScreenState();
}

class _WeeklyArchiveReviewScreenState extends State<WeeklyArchiveReviewScreen> {
  WeeklyArchiveReview? _review;
  ShareableArchiveProof? _shareProof;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewReview;
    if (preview != null) {
      _review = preview;
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
      _review = WeeklyArchiveReviewEngine.build(entries: entries);
      _shareProof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: entries,
      );
      _loading = false;
    });
  }

  void _goToRecord() {
    context.go('/record');
  }

  void _goToEvidence() {
    context.push(BeliefEvidenceNavigation.route);
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

    final review = _review ?? WeeklyArchiveReview.insufficient();

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
                review.title,
                key: const Key('weekly_archive_review_screen_title'),
                style: VoiceMemoryTypography.headlineStyle(),
              ),
              if (review.subtitle case final subtitle?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  key: const Key('weekly_archive_review_screen_subtitle'),
                  style: VoiceMemoryTypography.bodyStyle(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              WeeklyArchiveReviewCard(
                review: review,
                onAddAnother: review.hasEnoughEvidence ? _goToRecord : null,
                onViewEvidence: review.hasEnoughEvidence ? _goToEvidence : null,
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
