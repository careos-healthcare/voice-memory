import 'package:flutter/material.dart';

import '../../features/language/language_model.dart';
import '../../features/language/localized_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Subtle, non-blocking indicator of the detected reflection language.
///
/// Tapping it opens a small sheet to manually override the language. It is
/// intentionally quiet — it never blocks recording and only matters when a
/// non-English language is in play.
class LanguageIndicatorChip extends StatelessWidget {
  const LanguageIndicatorChip({
    super.key,
    required this.languageCode,
    required this.detectedCode,
    required this.onSelected,
  });

  /// Currently active UI language code.
  final String languageCode;

  /// Originally detected language code (used by "Use detected language").
  final String detectedCode;

  /// Called with the chosen language code after the override sheet closes.
  final ValueChanged<String> onSelected;

  Future<void> _openSheet(BuildContext context) async {
    final chosen = await showReflectionLanguageSheet(
      context: context,
      detectedCode: detectedCode,
      languageCode: languageCode,
    );
    if (chosen != null) onSelected(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final prefix = localized('languageLabelPrefix', languageCode);
    final label = '$prefix: ${languageDisplayName(languageCode)}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () => _openSheet(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: VoiceMemoryTypography.metadataStyle(
                      color: AppColors.textSecondary,
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

/// Opens the reflection-language override sheet, returning the chosen code or
/// null when dismissed. "Use detected language" resolves to [detectedCode].
Future<String?> showReflectionLanguageSheet({
  required BuildContext context,
  required String detectedCode,
  String languageCode = 'en',
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.backgroundSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                localized('reflectionLanguageTitle', languageCode),
                style: VoiceMemoryTypography.sectionTitleStyle(),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final lang in kSupportedLanguages)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lang.displayName),
                  onTap: () => Navigator.of(ctx).pop(lang.code),
                ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localized('useDetectedLanguage', languageCode)),
                onTap: () => Navigator.of(ctx).pop(detectedCode),
              ),
            ],
          ),
        ),
      );
    },
  );
}
