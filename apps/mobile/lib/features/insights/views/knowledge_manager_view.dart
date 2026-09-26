import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/insights/knowledge_catalog.dart';
import 'package:archiveme_mobile/features/insights/knowledge_forget_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// People, places, and themes the journal has already named.
class KnowledgeManagerView extends StatefulWidget {
  const KnowledgeManagerView({
    this.initialEntries,
    this.contacts = const [],
    this.forgotten = const {},
    this.onForget,
    super.key,
  });

  final List<JournalEntry>? initialEntries;
  final List<ArchiveFact> contacts;
  final Set<String> forgotten;
  final Future<void> Function(KnowledgeItem item)? onForget;

  static const title = 'What I Know';

  @override
  State<KnowledgeManagerView> createState() => _KnowledgeManagerViewState();
}

class _KnowledgeManagerViewState extends State<KnowledgeManagerView> {
  List<KnowledgeItem> _items = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final provided = widget.initialEntries;
    if (provided != null) {
      _items = buildKnowledgeCatalog(
        provided,
        contacts: widget.contacts,
        forgotten: widget.forgotten,
      );
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (!AppServices.isInitialized) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final entries = await AppServices.instance.journalStore.loadAll();
    final contacts = await FactLedgerStore.instance().loadAll();
    final forgotten = await ForgottenKnowledge.load(AppServices.instance.prefs);
    if (!mounted) return;
    setState(() {
      _items = buildKnowledgeCatalog(
        entries,
        contacts: contacts,
        forgotten: forgotten,
      );
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
            'Thoughtprint will stop listing this, and the cloud copy is removed when cloud features are on.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: Key('knowledge_forget_confirm_${item.label}'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Forget this'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final forget = widget.onForget ?? KnowledgeForgetService().forget;
    await forget(item);
    if (!mounted) return;
    setState(() {
      _items = [
        for (final current in _items)
          if (current.kind != item.kind ||
              current.label.toLowerCase() != item.label.toLowerCase())
            current,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(KnowledgeManagerView.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Text(
                'Nothing saved here yet.',
                key: Key('knowledge_manager_empty'),
              ),
            )
          : ListView(
              key: const Key('knowledge_manager_list'),
              children: [
                for (final kind in KnowledgeKind.values) ...[
                  if (_items.any((item) => item.kind == kind)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        _heading(kind),
                        key: Key('knowledge_heading_${kind.name}'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final item in _items.where(
                      (item) => item.kind == kind,
                    ))
                      _KnowledgeRow(item: item, onForget: () => _forget(item)),
                  ],
                ],
              ],
            ),
    );
  }

  String _heading(KnowledgeKind kind) {
    return switch (kind) {
      KnowledgeKind.people => 'People',
      KnowledgeKind.places => 'Places',
      KnowledgeKind.themes => 'Themes',
    };
  }
}

class _KnowledgeRow extends StatelessWidget {
  const _KnowledgeRow({required this.item, required this.onForget});

  final KnowledgeItem item;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('knowledge_row_${item.kind.name}_${item.label}'),
      direction: DismissDirection.endToStart,
      background: const ColoredBox(
        color: Color(0xFFB42318),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Text('Forget this'),
          ),
        ),
      ),
      confirmDismiss: (_) async {
        onForget();
        return false;
      },
      child: ExpansionTile(
        key: Key('knowledge_item_${item.label}'),
        title: Text(item.label),
        subtitle: ViewEvidenceInlineLink(
          entryIds: item.entryIds,
          surface: 'knowledge_manager',
          claimContext: item.label,
        ),
        trailing: TextButton(
          key: Key('knowledge_forget_${item.label}'),
          onPressed: onForget,
          child: const Text('Forget this'),
        ),
        children: [
          for (final entry in item.citations)
            ListTile(
              key: Key('knowledge_citation_${entry.id}'),
              title: Text(
                entry.transcript.trim().isEmpty
                    ? item.label
                    : entry.transcript.trim(),
              ),
            ),
        ],
      ),
    );
  }
}
