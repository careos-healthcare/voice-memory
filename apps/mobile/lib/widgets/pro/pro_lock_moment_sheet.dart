import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pro_lock_moment/pro_lock_moment_analytics.dart';
import 'package:archiveme_mobile/features/pro_lock_moment/pro_lock_moment_engine.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Sheet for the Pro lock moment — first proof context and Pro value.
class ProLockMomentSheet extends StatelessWidget {
  const ProLockMomentSheet({
    required this.source, required this.entryCount, required this.hasFirstProof, required this.hasConfirmedRepeat, required this.onSeePro, super.key,
  });

  final String source;
  final int entryCount;
  final bool hasFirstProof;
  final bool hasConfirmedRepeat;
  final VoidCallback onSeePro;

  static Future<void> show(
    BuildContext context, {
    required String source,
    required int entryCount,
    required bool hasFirstProof,
    required bool hasConfirmedRepeat,
    required VoidCallback onSeePro,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ProLockMomentSheet(
        source: source,
        entryCount: entryCount,
        hasFirstProof: hasFirstProof,
        hasConfirmedRepeat: hasConfirmedRepeat,
        onSeePro: onSeePro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = ProLockMomentEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                display.sheetTitle,
                key: const Key('pro_lock_moment_sheet_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.title,
                key: const Key('pro_lock_moment_sheet_proof_title'),
                style: ArchiveMobileTypography.listTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                display.body,
                key: const Key('pro_lock_moment_sheet_body'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.paidReason,
                key: const Key('pro_lock_moment_sheet_paid_reason'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                display.chatDifferentiation,
                key: const Key('pro_lock_moment_sheet_chatgpt_line'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('pro_lock_moment_sheet_see_pro'),
                onPressed: () {
                  ProLockMomentAnalytics.ctaTapped(
                    source: source,
                    entryCount: entryCount,
                    hasFirstProof: hasFirstProof,
                    hasConfirmedRepeat: hasConfirmedRepeat,
                    actionType: 'see_pro',
                  );
                  Navigator.of(context).pop();
                  onSeePro();
                },
                child: Text(display.cta),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('pro_lock_moment_sheet_close'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(display.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}