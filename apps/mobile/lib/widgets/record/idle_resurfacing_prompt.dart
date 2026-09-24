import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// One older moment, shown above the idle recorder when history exists.
class IdleResurfacingPrompt extends StatefulWidget {
  const IdleResurfacingPrompt({super.key});

  @override
  State<IdleResurfacingPrompt> createState() => _IdleResurfacingPromptState();
}

class _IdleResurfacingPromptState extends State<IdleResurfacingPrompt> {
  JournalEntry? _entry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await AppServices.instance.journalStore.loadAll();
      if (!mounted || entries.isEmpty) return;
      final sorted = [...entries]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final older = sorted.where(
        (entry) => DateTime.now().difference(entry.createdAt).inDays >= 14,
      );
      setState(() => _entry = older.isEmpty ? sorted.first : older.first);
    } catch (_) {
      // No store yet, or the archive is empty. The idle screen stays quiet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) return const SizedBox.shrink();
    final quote = entry.transcript.trim();
    final snippet = quote.length > 90 ? '${quote.substring(0, 90)}…' : quote;
    if (snippet.isEmpty) return const SizedBox.shrink();
    final days = DateTime.now().difference(entry.createdAt).inDays;
    final lead = days >= 14
        ? 'Three weeks ago you said…'
        : 'From an earlier moment…';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lead,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(snippet, style: Theme.of(context).textTheme.bodyLarge),
          ViewEvidenceInlineLink(
            entryIds: [entry.id],
            surface: 'idle_recording',
            claimContext: lead,
          ),
        ],
      ),
    );
  }
}
