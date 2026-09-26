import 'dart:async';

import 'package:archiveme_mobile/features/insights/knowledge_catalog.dart';
import 'package:archiveme_mobile/features/insights/knowledge_forget_service.dart';
import 'package:archiveme_mobile/features/memory/entry_embedding_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// People, places, and themes remembered on this phone.
class WhatThoughtprintRemembersScreen extends StatefulWidget {
  const WhatThoughtprintRemembersScreen({
    this.initialEntries,
    this.store,
    super.key,
  });

  final List<JournalEntry>? initialEntries;
  final EntryEmbeddingStore? store;

  static const title = 'What Thoughtprint remembers';

  @override
  State<WhatThoughtprintRemembersScreen> createState() =>
      _WhatThoughtprintRemembersScreenState();
}

class _WhatThoughtprintRemembersScreenState
    extends State<WhatThoughtprintRemembersScreen> {
  List<KnowledgeItem> _items = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  EntryEmbeddingStore? get _store {
    if (widget.store != null) return widget.store;
    if (!AppServices.isInitialized) return null;
    return EntryEmbeddingStore(AppServices.instance.sqliteDatabase.database);
  }

  Future<void> _load() async {
    final provided = widget.initialEntries;
    final entries = provided ??
        (AppServices.isInitialized
            ? await AppServices.instance.journal.loadAll()
            : const <JournalEntry>[]);
    final hidden = await _store?.hiddenLabels() ?? {};
    if (!mounted) return;
    setState(() {
      _items = buildKnowledgeCatalog(entries, forgotten: hidden);
      _loading = false;
    });
  }

  Future<void> _forget(KnowledgeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Forget ${item.label}?'),
          content: const Text(
            'Thoughtprint will stop using this in memory. The journal entries stay on this phone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: Key('memory_forget_confirm_${item.label}'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Forget this'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final store = _store;
    if (store != null) {
      await store.hideLabel(item.label);
      for (final entry in item.citations) {
        await store.hideEntry(entry.id);
      }
    }
    if (AppServices.isInitialized) {
      await ForgottenKnowledge.remember(
        AppServices.instance.prefs,
        item.label,
      );
    }
    if (!mounted) return;
    setState(() {
      _items = [
        for (final current in _items)
          if (current.label.toLowerCase() != item.label.toLowerCase() ||
              current.kind != item.kind)
            current,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('what_thoughtprint_remembers'),
      appBar: AppBar(title: const Text(WhatThoughtprintRemembersScreen.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Text(
                'Nothing remembered yet.',
                key: Key('what_thoughtprint_remembers_empty'),
              ),
            )
          : ListView(
              children: [
                for (final kind in KnowledgeKind.values)
                  if (_items.any((item) => item.kind == kind)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        switch (kind) {
                          KnowledgeKind.people => 'People',
                          KnowledgeKind.places => 'Places',
                          KnowledgeKind.themes => 'Themes',
                        },
                      ),
                    ),
                    for (final item in _items.where((item) => item.kind == kind))
                      ListTile(
                        key: Key('memory_item_${item.label}'),
                        title: Text(item.label),
                        subtitle: ViewEvidenceInlineLink(
                          entryIds: item.entryIds,
                          surface: 'what_thoughtprint_remembers',
                          claimContext: item.label,
                        ),
                        trailing: TextButton(
                          key: Key('memory_forget_${item.label}'),
                          onPressed: () => unawaited(_forget(item)),
                          child: const Text('Forget this'),
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}
