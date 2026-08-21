import 'package:archiveme_mobile/features/memory/entry_thread_scope.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Sheet to name a new archive thread. The name stays local only.
Future<String?> showNewThreadSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _NewThreadSheet(),
  );
}

class _NewThreadSheet extends StatefulWidget {
  const _NewThreadSheet();

  @override
  State<_NewThreadSheet> createState() => _NewThreadSheetState();
}

class _NewThreadSheetState extends State<_NewThreadSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EntryThreadScopeCopy.newThreadLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('new_thread_name_field'),
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Thread name'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('new_thread_create_cta'),
            onPressed: _submit,
            child: const Text('Create thread'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}