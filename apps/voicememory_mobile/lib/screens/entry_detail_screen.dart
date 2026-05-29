import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/scaffold_shell.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  JournalEntry? _entry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await AppServices.instance.journalStore.getById(widget.entryId);
    if (mounted) setState(() => _entry = e);
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    if (e == null) {
      return ScaffoldShell(
        title: 'Entry',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final r = e.reflection;
    return ScaffoldShell(
      title: 'Reflection',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            e.createdAt.toLocal().toString(),
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text('Transcript', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(e.transcript),
          const SizedBox(height: 24),
          Text('Reflection', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (r.exactLanguagePattern.isNotEmpty)
            _field('Exact words', r.exactLanguagePattern),
          if (r.concreteObservation.isNotEmpty)
            _field('Observation', r.concreteObservation),
          if (r.repeatedSignal.isNotEmpty) _field('Repeated', r.repeatedSignal),
          if (r.tensionOrContradiction != null &&
              r.tensionOrContradiction!.isNotEmpty)
            _field('Tension', r.tensionOrContradiction!),
          if (r.avoidedOrVagueArea != null && r.avoidedOrVagueArea!.isNotEmpty)
            _field('Indirect', r.avoidedOrVagueArea!),
          if (r.nextSmallAction != null && r.nextSmallAction!.isNotEmpty)
            _field('Next step', r.nextSmallAction!),
          if (r.mood.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Mood: ${r.mood}', style: const TextStyle(color: AppTheme.muted)),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
