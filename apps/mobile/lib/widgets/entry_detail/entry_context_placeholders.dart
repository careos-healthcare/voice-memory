import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';

/// Placeholders for photo, place, and state of mind on a saved moment.
class EntryContextPlaceholders extends StatelessWidget {
  const EntryContextPlaceholders({
    required this.entry,
    super.key,
    this.onPlace,
    this.onMood,
  });

  final JournalEntry entry;
  final ValueChanged<String>? onPlace;
  final ValueChanged<String>? onMood;

  @override
  Widget build(BuildContext context) {
    final photo = entry.imageEvidence?.caption.trim();
    final place = entry.display.locationLabel?.trim();
    final mood = entry.reflection.mood.trim();
    return Wrap(
      key: const Key('entry_context_placeholders'),
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          icon: Icons.photo_outlined,
          label: (photo == null || photo.isEmpty) ? 'Photo' : photo,
          onTap: null,
        ),
        _Chip(
          icon: Icons.place_outlined,
          label: (place == null || place.isEmpty) ? 'Place' : place,
          onTap: onPlace == null
              ? null
              : () => _ask(context, 'Place', onPlace!),
        ),
        _Chip(
          icon: Icons.mood_outlined,
          label: mood.isEmpty ? 'State of mind' : mood,
          onTap: onMood == null ? null : () => _ask(context, 'State of mind', onMood!),
        ),
      ],
    );
  }

  Future<void> _ask(
    BuildContext context,
    String title,
    ValueChanged<String> onSubmit,
  ) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) onSubmit(value);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
