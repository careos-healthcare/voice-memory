import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Top-left back control for pushed consumer screens (warm light, no AppBar).
class ConsumerScreenBackHeader extends StatelessWidget {
  const ConsumerScreenBackHeader({
    super.key,
    this.fallbackRoute = '/archive-belief',
    this.showLabel = true,
  });

  final String fallbackRoute;
  final bool showLabel;

  Future<void> _onBack(BuildContext context) async {
    final popped = await Navigator.maybePop(context);
    if (!popped && context.mounted) {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('consumer_screen_back_header'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _onBack(context),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.accentPrimary,
        ),
        label: showLabel
            ? Text(
                'Back',
                style: VoiceMemoryTypography.metadataStyle(
                  color: AppColors.accentPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}