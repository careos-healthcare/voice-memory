import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/user_facing_date.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

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
    return PushedScreenShell(
      title: 'Reflection',
      showBottomDone: false,
      body: e == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  formatUserFacingDate(e.createdAt),
                  style: const TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Transcript', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(e.transcript),
                const SizedBox(height: 24),
                Text('Reflection', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ..._reflectionFields(e),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Done'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => context.go('/archive-belief'),
                          child: const Text('Return to Archive'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  List<Widget> _reflectionFields(JournalEntry e) {
    final r = e.reflection;
    final fields = <Widget>[];
    void add(String label, String value) {
      if (value.isEmpty) return;
      fields.add(_field(label, value));
    }

    add('Exact words', r.exactLanguagePattern);
    add('Observation', r.concreteObservation);
    add('Repeated', r.repeatedSignal);
    if (r.tensionOrContradiction != null) {
      add('Tension', r.tensionOrContradiction!);
    }
    if (r.avoidedOrVagueArea != null) {
      add('Indirect', r.avoidedOrVagueArea!);
    }
    if (r.nextSmallAction != null) {
      add('Next step', r.nextSmallAction!);
    }
    if (r.mood.isNotEmpty) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Mood: ${r.mood}',
            style: const TextStyle(color: AppTheme.muted),
          ),
        ),
      );
    }
    return fields;
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}
