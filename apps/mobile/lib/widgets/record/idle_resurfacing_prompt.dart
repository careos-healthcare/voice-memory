import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// One older moment, shown above the idle recorder when history exists.
class IdleResurfacingPrompt extends StatefulWidget {
  const IdleResurfacingPrompt({super.key, this.onDark = false});

  /// Cream type for the dark recording canvas.
  final bool onDark;

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
        ? '3 weeks ago you said…'
        : 'From an earlier moment…';
    final theme = Theme.of(context);
    final leadColor = widget.onDark
        ? const Color(0xFFB7C0CC)
        : theme.colorScheme.onSurface;
    final quoteColor = widget.onDark
        ? const Color(0xFFF8F6F1)
        : theme.colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.onDark ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lead,
            key: const Key('recording_resurfacing_lead'),
            style: theme.textTheme.titleMedium?.copyWith(color: leadColor),
          ),
          const SizedBox(height: 6),
          Text(
            snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: quoteColor,
              fontFamily: 'Newsreader',
            ),
          ),
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
