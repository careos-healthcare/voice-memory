import 'package:flutter/material.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/warm_archive_copy.dart';
import '../features/archive_challenge/archive_challenge_engine.dart';
import '../features/archive_challenge/archive_challenge_models.dart';
import '../features/archive_challenge/archive_challenge_store.dart';
import '../features/archive_explanations/archive_explanation_analytics.dart';
import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../services/product_analytics.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Discover — one active archive challenge below daily discovery.
class ArchiveChallengeSection extends StatefulWidget {
  const ArchiveChallengeSection({super.key, required this.entries, this.state});

  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? state;

  @override
  State<ArchiveChallengeSection> createState() =>
      _ArchiveChallengeSectionState();
}

class _ArchiveChallengeSectionState extends State<ArchiveChallengeSection> {
  ArchiveChallenge? _challenge;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArchiveChallengeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final store = ArchiveChallengeStore(AppServices.instance.prefs);
    final challenge = await const ArchiveChallengeEngine().loadActiveChallenge(
      store: store,
      entries: widget.entries,
      state: widget.state,
    );
    if (!mounted) return;
    setState(() {
      _challenge = challenge;
      _loading = false;
    });
    if (challenge != null) {
      ProductAnalytics.trackStrings('archive_challenge_surfaced', {
        'id': challenge.id,
        'evidence_count': challenge.evidenceCount.toString(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _challenge == null) return const SizedBox.shrink();

    final c = _challenge!;
    final evidenceLabel = c.evidenceCount == 1
        ? '1 supporting recording'
        : '${c.evidenceCount} supporting recordings';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          WarmArchiveCopy.challengeSectionTitle,
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.primaryIndigo,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoiceMemoryColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.headline,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                evidenceLabel,
                style: VoiceMemoryTypography.metadataStyle(
                  color: VoiceMemoryColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ArchiveExplanationAnalytics.challengeViewed(refId: c.id);
                  ProductAnalytics.trackStrings(
                    'archive_challenge_why_opened',
                    {'id': c.id},
                  );
                  openArchiveExplanation(
                    context,
                    ref: c.insightRef,
                    askPrompt: c.insightRef.askPrompt ?? c.body,
                    askCitedEntryIds: c.evidenceEntryIds,
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: VoiceMemoryColors.primaryIndigo,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Why?',
                  style: VoiceMemoryTypography.bodyStyle(
                    color: VoiceMemoryColors.primaryIndigo,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ArchiveMobileSpacing.md),
      ],
    );
  }
}
