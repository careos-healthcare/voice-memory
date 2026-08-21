import 'package:archiveme_mobile/models/journal_entry.dart';

enum ArchiveBeliefLoadState { loading, loaded, error, offline }

sealed class ArchiveBeliefLoadResult {
  const ArchiveBeliefLoadResult();
}

final class ArchiveBeliefLoadSuccess extends ArchiveBeliefLoadResult {
  const ArchiveBeliefLoadSuccess(this.entries);

  final List<JournalEntry> entries;
}

final class ArchiveBeliefLoadOffline extends ArchiveBeliefLoadResult {
  const ArchiveBeliefLoadOffline();
}

final class ArchiveBeliefLoadFailure extends ArchiveBeliefLoadResult {
  const ArchiveBeliefLoadFailure();
}