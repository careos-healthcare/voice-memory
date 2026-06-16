import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/review/review_prompt_after_value.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Hosts the review prompt below the value-moment cards. Re-evaluates when
/// session value signals change (useful-yes, Pro retention yes, invite
/// copied) so the prompt can appear right after the moment, and latches
/// once shown so it survives parent rebuilds until closed.
class ReviewPromptSection extends StatefulWidget {
  const ReviewPromptSection({
    super.key,
    required this.entryCount,
    required this.hasWeeklyReview,
    this.store,
    this.launcher,
  });

  final int entryCount;
  final bool hasWeeklyReview;

  /// Injectable for tests; defaults to the app-services-backed store.
  final ReviewPromptStore? store;

  /// Injectable for tests; defaults to the safe no-op launcher.
  final ReviewLauncher? launcher;

  @override
  State<ReviewPromptSection> createState() => _ReviewPromptSectionState();
}

class _ReviewPromptSectionState extends State<ReviewPromptSection> {
  bool _askedLoaded = false;
  bool _alreadyAsked = false;
  bool _showing = false;
  String _source = '';

  ReviewPromptStore get _store => widget.store ?? ReviewPromptStore();

  @override
  void initState() {
    super.initState();
    ReviewPromptAfterValue.changes.addListener(_reevaluate);
    unawaited(_loadAsked());
  }

  @override
  void dispose() {
    ReviewPromptAfterValue.changes.removeListener(_reevaluate);
    super.dispose();
  }

  Future<void> _loadAsked() async {
    final asked = await _store.asked();
    if (!mounted) return;
    setState(() {
      _askedLoaded = true;
      _alreadyAsked = asked;
    });
  }

  void _reevaluate() {
    if (!mounted || _showing) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_showing) {
      if (!_askedLoaded ||
          !ReviewPromptAfterValue.shouldShow(
            entryCount: widget.entryCount,
            hasWeeklyReview: widget.hasWeeklyReview,
            alreadyAsked: _alreadyAsked,
          )) {
        return const SizedBox.shrink();
      }
      _showing = true;
      ReviewPromptAfterValue.shownThisSession = true;
      _source =
          ReviewPromptAfterValue.sourceFor(
            entryCount: widget.entryCount,
            hasWeeklyReview: widget.hasWeeklyReview,
          ) ??
          '';
      // Asked once, ever — persisted at first render so neither tap nor
      // dismiss is needed to stop future prompts.
      unawaited(_store.markAsked());
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ReviewPromptCard(
        source: _source,
        entryCount: widget.entryCount,
        launcher: widget.launcher ?? const NoopReviewLauncher(),
        onClosed: () => setState(() {
          ReviewPromptAfterValue.dismissedThisSession = true;
          _showing = false;
        }),
      ),
    );
  }
}

/// The review prompt itself: calm copy, one CTA into the native review
/// abstraction, and a clear "Not now". Dismissing just closes the card —
/// no follow-up, no second ask.
class ReviewPromptCard extends StatelessWidget {
  const ReviewPromptCard({
    super.key,
    required this.source,
    required this.entryCount,
    required this.launcher,
    required this.onClosed,
  });

  /// Stable id of the value moment that made the prompt eligible.
  final String source;

  final int entryCount;

  final ReviewLauncher launcher;

  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.reviewPromptSeen,
      source: source,
      cardType: source,
      entryCount: entryCount,
      oncePerSession: true,
    );

    return Container(
      key: const Key('review_prompt_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F5F1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ReviewPromptAfterValue.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ReviewPromptAfterValue.body,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TextButton(
                  key: const Key('review_prompt_dismiss'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.reviewPromptDismissed,
                      source: source,
                      cardType: source,
                      entryCount: entryCount,
                    );
                    onClosed();
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  child: const Text(
                    ReviewPromptAfterValue.dismissLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: FilledButton(
                  key: const Key('review_prompt_cta'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.reviewPromptTapped,
                      source: source,
                      cardType: source,
                      entryCount: entryCount,
                    );
                    unawaited(launcher.requestReview());
                    onClosed();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  child: const Text(
                    ReviewPromptAfterValue.ctaLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
