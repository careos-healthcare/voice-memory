import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive/archive_beliefs_dashboard.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Archive subsection — absent until [ArchiveChangesEligibility] passes.
class ArchiveChangesSection extends StatefulWidget {
  const ArchiveChangesSection({
    super.key,
    this.previewSnapshot,
  });

  @visibleForTesting
  final ArchiveChangesSnapshot? previewSnapshot;

  @override
  State<ArchiveChangesSection> createState() => _ArchiveChangesSectionState();
}

class _ArchiveChangesSectionState extends State<ArchiveChangesSection> {
  ArchiveChangesSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewSnapshot;
    if (preview != null) {
      _snapshot = preview;
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await ArchiveChangesAdapter.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.eligible) {
      return const SizedBox.shrink(key: Key('archive_changes_section_absent'));
    }

    return Padding(
      key: const Key('archive_changes_section'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BeliefProductCopy.changesTabLabel,
            key: const Key('archive_changes_heading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.changesScreenLead,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.changesSectionCorrectionHint,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BeliefChangeStories(items: snapshot.timeline),
        ],
      ),
    );
  }
}
