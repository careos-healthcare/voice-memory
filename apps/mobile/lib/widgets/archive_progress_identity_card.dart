import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/retention/archive_progress_identity.dart';
import 'package:archiveme_mobile/features/retention/retention_analytics.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hero progress card — indigo gradient centerpiece on Discover.
class ArchiveProgressIdentityCard extends StatefulWidget {
  const ArchiveProgressIdentityCard({
    required this.identity, super.key,
    this.previous,
  });

  final ArchiveProgressIdentity identity;
  final ArchiveProgressIdentity? previous;

  @override
  State<ArchiveProgressIdentityCard> createState() =>
      _ArchiveProgressIdentityCardState();
}

class _ArchiveProgressIdentityCardState
    extends State<ArchiveProgressIdentityCard> {
  var _loggedView = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loggedView) {
      _loggedView = true;
      RetentionAnalytics.progressIdentityViewed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.identity;
    final prev = widget.previous;

    if (id.recordings == 0) {
      return Semantics(
        label: IntentionalEmptyArchiveContent.semanticsLabel,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            gradient: VoiceMemoryColors.progressHeroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                EmptyArchiveCopy.progressEmptyTitle,
                style: VoiceMemoryTypography.sectionTitleStyle(
                  color: VoiceMemoryColors.onPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                EmptyArchiveCopy.progressEmptyBody,
                style: VoiceMemoryTypography.bodyStyle(
                  color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.9),
                ).copyWith(height: 1.45),
              ),
              const SizedBox(height: 16),
              CaptureEntryActions(
                onRecord: () => goToFirstRecording(context),
                onGradient: true,
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: 'Your archive progress',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          gradient: VoiceMemoryColors.progressHeroGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Archive',
              style: VoiceMemoryTypography.sectionTitleStyle(
                color: VoiceMemoryColors.onPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _HeroMetric(
              '${id.recordings} recordings',
              increased: prev != null && id.recordings > prev.recordings,
            ),
            _HeroMetric(
              '${id.themesDiscovered} themes discovered',
              increased:
                  prev != null && id.themesDiscovered > prev.themesDiscovered,
            ),
            _HeroMetric(
              '${id.beliefChanges} belief changes',
              increased: prev != null && id.beliefChanges > prev.beliefChanges,
            ),
            _HeroMetric(
              '${id.activeLifeChapters} active life chapters',
              increased:
                  prev != null &&
                  id.activeLifeChapters > prev.activeLifeChapters,
            ),
            const SizedBox(height: 12),
            Text(
              'Archive age: ${id.archiveAgeDays} days',
              style: VoiceMemoryTypography.metadataStyle(
                color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.88),
              ),
            ),
            Text(
              'Current streak: ${id.currentStreak} days',
              style: VoiceMemoryTypography.metadataStyle(
                color: id.currentStreak > 0
                    ? VoiceMemoryColors.success
                    : VoiceMemoryColors.onPrimary.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push('/weekly-story'),
              style: TextButton.styleFrom(
                foregroundColor: VoiceMemoryColors.onPrimary,
                backgroundColor: VoiceMemoryColors.onPrimary.withValues(
                  alpha: 0.16,
                ),
                minimumSize: const Size(48, 48),
              ),
              child: const Text('View Growth'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(this.label, {required this.increased});

  final String label;
  final bool increased;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: increased ? 0.96 : 1, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: VoiceMemoryColors.onPrimary,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}