import '../../models/journal_entry.dart';
import 'transcription_job.dart';

final class TranscriptionTimelineSnapshot {
  const TranscriptionTimelineSnapshot({
    required this.entries,
    required this.pendingJobs,
  });

  final List<JournalEntry> entries;
  final List<TranscriptionJob> pendingJobs;
}
