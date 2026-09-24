import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consumer colors, type, and spacing use the shared tokens', () {
    expect(AppColors.backgroundPrimary, ArchiveDesignTokens.background);
    expect(AppColors.backgroundSecondary, ArchiveDesignTokens.surface);
    expect(AppColors.textPrimary, ArchiveDesignTokens.foreground);
    expect(AppColors.textSecondary, ArchiveDesignTokens.muted);
    expect(AppColors.accentPrimary, ArchiveDesignTokens.accent);
    expect(AppColors.borderSubtle, ArchiveDesignTokens.border);
    expect(AppColors.error, ArchiveDesignTokens.danger);

    expect(AppSpacing.xs, ArchiveDesignTokens.spaceXs);
    expect(AppSpacing.sm, ArchiveDesignTokens.spaceSm);
    expect(AppSpacing.md, ArchiveDesignTokens.spaceMd);
    expect(AppSpacing.lg, ArchiveDesignTokens.spaceLg);
    expect(AppSpacing.xl, ArchiveDesignTokens.spaceXl);

    expect(VoiceMemoryTypography.headline, ArchiveDesignTokens.fontHeadline);
    expect(VoiceMemoryTypography.sectionTitle, ArchiveDesignTokens.fontSection);
    expect(VoiceMemoryTypography.cardTitle, ArchiveDesignTokens.fontCard);
    expect(VoiceMemoryTypography.body, ArchiveDesignTokens.fontBody);
    expect(VoiceMemoryTypography.caption, ArchiveDesignTokens.fontCaption);

    final headline = VoiceMemoryTypography.headlineStyle();
    expect(headline.fontSize, 32);
    expect(headline.height, 1.35);
    expect(headline.letterSpacing, -0.4);
    expect(headline.fontWeight, ArchiveDesignTokens.weightHeadline);
  });
}
