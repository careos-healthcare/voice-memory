import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_analytics.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_copy.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Post-save watch card — no CTAs; Record screen owns Done / Record another.
class ComeBackTomorrowCard extends StatefulWidget {
  const ComeBackTomorrowCard({
    required this.watch, required this.entryCount, super.key,
    this.store,
    this.skipPersist = false,
  });

  const ComeBackTomorrowCard.test({
    required this.watch, required this.entryCount, super.key,
    this.store,
  }) : skipPersist = true;

  final ComeBackTomorrowPostSaveWatch watch;
  final int entryCount;
  final ComeBackTomorrowV2Store? store;
  final bool skipPersist;

  @override
  State<ComeBackTomorrowCard> createState() => _ComeBackTomorrowCardState();
}

class _ComeBackTomorrowCardState extends State<ComeBackTomorrowCard> {
  bool _tracked = false;
  bool _persisted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_trackAndPersist());
  }

  Future<void> _trackAndPersist() async {
    if (_tracked) return;
    _tracked = true;
    ComeBackTomorrowV2Analytics.watchSet(
      source: widget.watch.source,
      entryCount: widget.entryCount,
      hasWatchTarget: true,
    );
    if (widget.skipPersist || _persisted) return;
    _persisted = true;
    final store = widget.store ?? ComeBackTomorrowV2Store.instance();
    await store.setWatchTarget(
      watchKey: ComeBackTomorrowV2Store.watchKeyForPhrase(
        widget.watch.groundedPhrase,
      ),
      groundedPhrase: widget.watch.groundedPhrase,
      source: widget.watch.source,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);
    final phraseStyle = bodyStyle.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      key: const Key('come_back_tomorrow_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.watch.title,
            key: const Key('come_back_tomorrow_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.watch.body,
            key: const Key('come_back_tomorrow_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ComeBackTomorrowV2Copy.quotedPhrase(widget.watch.groundedPhrase),
            key: const Key('come_back_tomorrow_phrase'),
            style: phraseStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.watch.footer,
            key: const Key('come_back_tomorrow_footer'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}