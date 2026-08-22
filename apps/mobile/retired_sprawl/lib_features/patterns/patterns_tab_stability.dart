import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Logging and safe fallbacks for the Patterns tab.
abstract class PatternsTabStability {
  PatternsTabStability._();

  static void logTabBuild({
    required int entryCount,
    required int patternCount,
  }) {
    AppLogger.debug(
      'ARCHIVEME_PATTERNS_TAB_BUILD entryCount=$entryCount patternCount=$patternCount',
    );
  }

  static void logEmptyState(String reason) {
    AppLogger.debug('ARCHIVEME_PATTERNS_EMPTY_STATE reason=$reason');
  }

  static void logBuildFailed(String reason) {
    AppLogger.debug('ARCHIVEME_PATTERNS_BUILD_FAILED reason=$reason');
  }

  /// True when a belief card is safe to render on the Patterns dashboard.
  static bool hasRenderablePatternInsight({
    required ArchiveBeliefsSnapshot? beliefs,
    required ArchiveBeliefCardModel? strongest,
  }) {
    if (beliefs == null || strongest == null) return false;
    return strongest.statement.trim().isNotEmpty;
  }

  /// Guard for synchronous build failures in the Patterns tab shell.
  static Widget guard({
    required Widget Function() builder,
    required Widget Function() fallbackBuilder,
  }) {
    try {
      return builder();
    } catch (e, stackTrace) {
      logBuildFailed('$e');
      if (kDebugMode) {
        AppLogger.debug('$stackTrace');
      }
      return fallbackBuilder();
    }
  }
}

/// Shown when entries exist but no pattern insight is ready yet.
class PatternsNoClearPatternView extends StatelessWidget {
  const PatternsNoClearPatternView({super.key, this.fillViewport = false});

  final bool fillViewport;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    final content = Column(
      key: const Key('patterns_no_clear_pattern_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.patternsNoClearPatternTitle,
          style: ArchiveMobileTypography.responsivePageTitle(context),
        ),
        SizedBox(height: gap),
        Text(
          ConsumerUiCopy.patternsNoClearPatternBody,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
      ],
    );

    final padded = ArchiveResponsiveLayout.page(
      context: context,
      maxWidth: ArchiveResponsiveLayout.cardMaxWidth,
      child: content,
    );

    return SingleChildScrollView(
      physics: fillViewport
          ? const AlwaysScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      child: padded,
    );
  }
}