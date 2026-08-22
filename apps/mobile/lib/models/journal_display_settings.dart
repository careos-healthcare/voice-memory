import 'package:archiveme_mobile/models/journal_display_metadata.dart';

export 'journal_display_metadata.dart';
export 'package:archiveme_mobile/features/journal/presentation/models/journal_display_presentation.dart';

/// Deprecated alias — use [JournalDisplayMetadata] for persistence and
/// [JournalDisplayPresentation] for UI-facing display state.
@Deprecated('Use JournalDisplayMetadata for persistence or JournalDisplayPresentation for UI.')
typedef JournalDisplaySettings = JournalDisplayMetadata;
