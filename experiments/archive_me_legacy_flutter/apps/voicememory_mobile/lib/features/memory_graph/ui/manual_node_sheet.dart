import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../media/encrypted_image_engine.dart';
import '../../media/media_attachment.dart';
import '../../media/media_attachment_bar.dart';
import '../../media/media_picker_gateway.dart';
import '../models/manual_graph_models.dart';

class ManualNodeSheet extends StatefulWidget {
  const ManualNodeSheet({
    super.key,
    required this.onSave,
    this.imageEngine,
    this.mediaPicker,
  });

  final ValueChanged<ManualNodeDraft> onSave;
  final EncryptedImageEngine? imageEngine;
  final MediaPickerGateway? mediaPicker;

  @override
  State<ManualNodeSheet> createState() => _ManualNodeSheetState();
}

class _ManualNodeSheetState extends State<ManualNodeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _note = TextEditingController();
  ManualNodeCategory _category = ManualNodeCategory.idea;
  List<MediaAttachment> _attachments = const [];
  bool _attachmentsCommitted = false;

  @override
  void dispose() {
    if (!_attachmentsCommitted && widget.imageEngine != null) {
      for (final attachment in _attachments) {
        unawaited(widget.imageEngine!.delete(attachment));
      }
    }
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(
      ManualNodeDraft(
        label: _label.text,
        category: _category,
        note: _note.text.trim().isEmpty ? null : _note.text,
        mediaAttachments: _attachments,
      ),
    );
    _attachmentsCommitted = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Material(
        key: const Key('manual-node-sheet'),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create a Truth Anchor',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'User-defined nodes are locked at 100% confidence.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('manual-node-label'),
                      controller: _label,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Label'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a label'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ManualNodeCategory>(
                      key: const Key('manual-node-category'),
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final category in ManualNodeCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(_title(category.name)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) _category = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('manual-node-note'),
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Optional note',
                      ),
                    ),
                    const SizedBox(height: 12),
                    MediaAttachmentBar(
                      key: const Key('manual-node-media'),
                      attachments: _attachments,
                      onChanged: (attachments) {
                        setState(() => _attachments = attachments);
                      },
                      imageEngine: widget.imageEngine,
                      picker: widget.mediaPicker,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('manual-node-save'),
                      onPressed: _save,
                      icon: const Icon(Icons.push_pin),
                      label: const Text('Pin to Memory Graph'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
