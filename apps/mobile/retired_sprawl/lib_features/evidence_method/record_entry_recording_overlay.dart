import 'package:archiveme_mobile/features/evidence_method/record_entry_providers.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Persistent bottom bar shown while a record-entry session is active off-screen.
class RecordEntryRecordingOverlay extends ConsumerWidget {
  const RecordEntryRecordingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOverlay = ref.watch(recordEntryShowsGlobalOverlayProvider);
    if (!showOverlay) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: AppSpacing.sm,
      right: AppSpacing.sm,
      bottom: AppSpacing.sm,
      child: SafeArea(
        top: false,
        child: Material(
          elevation: 8,
          color: VoiceMemoryColors.primaryIndigo,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('record_entry_global_overlay'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/record-entry'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Recording in progress…',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: VoiceMemoryColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Return',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: VoiceMemoryColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}