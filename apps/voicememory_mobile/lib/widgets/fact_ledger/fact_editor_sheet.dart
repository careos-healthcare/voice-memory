import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/fact_ledger/archive_fact.dart';
import '../../features/fact_ledger/fact_ledger_store.dart';
import '../../features/timeline/timeline_entry_display.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

Future<bool> showFactEditorSheet(
  BuildContext context, {
  required FactLedgerStore store,
  ArchiveFact? existing,
  JournalEntry? entry,
  String? prefillLabel,
  String source = 'save_detail',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (context) => FactEditorSheet(
      store: store,
      existing: existing,
      entry: entry,
      prefillLabel: prefillLabel,
      source: source,
    ),
  ).then((value) => value ?? false);
}

class FactEditorSheet extends StatefulWidget {
  const FactEditorSheet({
    super.key,
    required this.store,
    this.existing,
    this.entry,
    this.prefillLabel,
    this.source = 'save_detail',
  });

  final FactLedgerStore store;
  final ArchiveFact? existing;
  final JournalEntry? entry;
  final String? prefillLabel;
  final String source;

  @override
  State<FactEditorSheet> createState() => _FactEditorSheetState();
}

class _FactEditorSheetState extends State<FactEditorSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _valueController;
  late final TextEditingController _noteController;
  late FactType _type;
  var _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final safeLabel =
        existing?.label ??
        widget.prefillLabel ??
        (widget.entry != null ? timelineEntryTitle(widget.entry!) : '');
    _labelController = TextEditingController(text: safeLabel);
    _valueController = TextEditingController(text: existing?.value ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _type = FactType.fromId(existing?.factType);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final label = _labelController.text.trim();
    final value = _valueController.text.trim();
    if (label.isEmpty || value.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_editing) {
        await widget.store.update(
          id: widget.existing!.id,
          label: label,
          value: value,
          note: _noteController.text,
          factType: _type.id,
          source: widget.source,
        );
      } else {
        final entry = widget.entry;
        await widget.store.create(
          sourceEntryId: entry?.id ?? widget.existing?.sourceEntryId ?? '',
          label: label,
          value: value,
          note: _noteController.text,
          factType: _type.id,
          archivePackId: entry?.archivePackId,
          archiveThreadId: entry?.archiveThreadId,
          source: widget.source,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final showCredentialHelper = _type == FactType.credentialReference;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editing ? FactLedgerCopy.edit : FactLedgerCopy.saveDetail,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<FactType>(
              key: const Key('fact_type_dropdown'),
              value: _type,
              decoration: const InputDecoration(
                labelText: FactLedgerCopy.typeField,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in FactType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('fact_label_field'),
              controller: _labelController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: FactLedgerCopy.labelField,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('fact_value_field'),
              controller: _valueController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: FactLedgerCopy.valueField,
                border: OutlineInputBorder(),
              ),
            ),
            if (showCredentialHelper) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                FactLedgerCopy.credentialHelper,
                key: const Key('fact_credential_helper'),
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('fact_note_field'),
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: FactLedgerCopy.noteField,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const Key('fact_save_button'),
                onPressed: _busy ? null : _save,
                child: const Text(FactLedgerCopy.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
