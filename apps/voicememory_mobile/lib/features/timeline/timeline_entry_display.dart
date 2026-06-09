import '../../api/api_error_message.dart';
import '../../config/app_config.dart';
import '../../models/journal_entry.dart';
import '../../models/sync_status.dart';
import '../../product/consumer_copy_guard.dart';

/// User-facing timeline card title — never transport errors or draft placeholders.
String timelineEntryTitle(JournalEntry entry) {
  final snippet = _transcriptSnippet(entry.transcript);
  if (snippet != null) return snippet;

  final summary = _reflectionSnippet(entry.reflectionSummary);
  if (summary != null) return summary;

  return _recordingDateTitle(entry.createdAt);
}

/// Short sync badge on timeline cards; null when fully synced.
String? timelineSyncBadgeLabel(SyncStatus status) {
  switch (status) {
    case SyncStatus.synced:
      return null;
    case SyncStatus.localOnly:
    case SyncStatus.pendingUpload:
      return 'Offline';
    case SyncStatus.error:
      return 'Sync error';
    case SyncStatus.conflict:
      return 'Review';
  }
}

String? _transcriptSnippet(String transcript) {
  final line = transcript.split('\n').first.trim();
  if (line.isEmpty || _isUnusableEntryText(line)) return null;
  return line;
}

String? _reflectionSnippet(String summary) {
  return ConsumerCopyGuard.userFacingObservation(summary);
}

String _recordingDateTitle(DateTime createdAt) {
  final local = createdAt.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return 'Recording · $month ${local.day}, ${local.year} · $h:$m';
}

bool _isUnusableEntryText(String text) {
  final lower = text.toLowerCase();
  if (lower.startsWith('[draft]')) return true;
  if (lower == 'voice reflection') return true;

  const blocked = [
    'connection refused',
    'backend url not configured',
    'saved offline',
    'saved locally',
    'saved as a draft',
    'upload pending',
    'transcribe when connected',
    'recording saved locally',
    'recording saved offline',
    'offline — saved as a draft',
    'you appear to be offline',
    'cloud processing pending',
    'saved on this device',
  ];

  for (final phrase in blocked) {
    if (lower.contains(phrase)) return true;
  }

  if (text.trim() == AppConfig.backendNotConfiguredMessage) return true;
  if (text.trim() == cloudBackendUnavailableMessage) return true;

  return false;
}
