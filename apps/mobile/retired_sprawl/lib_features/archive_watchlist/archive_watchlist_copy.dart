import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_models.dart';
import 'package:archiveme_mobile/features/pro_value/pro_value_copy.dart';

/// User-facing copy for the archive watchlist — no pressure or certainty.
abstract final class ArchiveWatchlistCopy {
  ArchiveWatchlistCopy._();

  static const maxThemes = 3;

  static const cardTitle = 'What should ArchiveMe watch for?';
  static const cardBody =
      'Choose a theme you want your archive to notice over time.';

  static const teaserTitle = 'What should ArchiveMe watch for?';
  static const teaserBody =
      'Save one moment first, then choose a theme for ArchiveMe to notice over time.';

  static const watchingForPrefix = 'Watching for:';
  static const addWhenShowsUp = 'Add moments when this shows up again.';
  static const matchHeadline = 'ArchiveMe found early evidence for this.';
  static const noMatchHeadline = 'No clear evidence yet.';
  static const noMatchBody = 'Add a moment when this shows up.';

  static const addThemeButton = 'Add watch theme';
  static const changeThemeButton = 'Change';
  static const removeThemeButton = 'Remove';
  static const customThemeButton = 'Custom theme';
  static const customThemeSheetTitle = 'Your watch theme';
  static const customThemeHint = 'What should ArchiveMe notice?';
  static const customThemeSave = 'Save theme';
  static const customThemeCancel = 'Cancel';

  static const privacyLine = 'Watch themes stay on this device.';

  static const String proLineLongTerm = ProValueCopy.cardProLine;
  static const String proPreviewButton = ProValueCopy.proPreviewButton;

  static String get themeLimitBody =>
      'Three watch themes is enough for this version. ${ProValueCopy.cardProLine}';

  static const presetUnclearDecisions = ArchiveWatchlistPreset(
    id: 'unclear_decisions',
    label: 'Unclear decisions',
  );
  static const presetWorkPatterns = ArchiveWatchlistPreset(
    id: 'work_patterns',
    label: 'Work patterns',
  );
  static const presetRepeatedThoughts = ArchiveWatchlistPreset(
    id: 'repeated_thoughts',
    label: 'Repeated thoughts',
  );
  static const presetLighterAfterWriting = ArchiveWatchlistPreset(
    id: 'lighter_after_writing',
    label: 'Moments that feel lighter after writing',
  );
  static const presetAvoidedTasks = ArchiveWatchlistPreset(
    id: 'avoided_tasks',
    label: 'Avoided tasks',
  );

  static const presets = <ArchiveWatchlistPreset>[
    presetUnclearDecisions,
    presetWorkPatterns,
    presetRepeatedThoughts,
    presetLighterAfterWriting,
    presetAvoidedTasks,
  ];

  static String matchCountLine(int count) {
    final word = count == 1 ? 'moment' : 'moments';
    return '$count saved $word may relate to this theme.';
  }

  static String watchingForLine(String label) => '$watchingForPrefix $label';

  static Iterable<String> allVisibleCopy() sync* {
    yield cardTitle;
    yield cardBody;
    yield teaserTitle;
    yield teaserBody;
    yield watchingForPrefix;
    yield addWhenShowsUp;
    yield matchHeadline;
    yield noMatchHeadline;
    yield noMatchBody;
    yield addThemeButton;
    yield changeThemeButton;
    yield removeThemeButton;
    yield customThemeButton;
    yield customThemeSheetTitle;
    yield customThemeHint;
    yield customThemeSave;
    yield customThemeCancel;
    yield privacyLine;
    yield proLineLongTerm;
    yield proPreviewButton;
    yield themeLimitBody;
    for (final preset in presets) {
      yield preset.label;
    }
    yield matchCountLine(2);
    yield watchingForLine('Unclear decisions');
  }
}