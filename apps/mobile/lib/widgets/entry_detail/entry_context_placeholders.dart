import 'dart:async';

import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:archiveme_mobile/features/health/health_state_of_mind_chip.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry_detail/current_place_lookup.dart';
import 'package:flutter/material.dart';

/// Place and state of mind on a saved moment.
///
/// Photo stays off this screen until photo support ships.
class EntryContextPlaceholders extends StatelessWidget {
  const EntryContextPlaceholders({
    required this.entry,
    super.key,
    this.onPlace,
    this.onMood,
    this.lookupCurrentPlace = lookupCurrentPlaceName,
  });

  static const moodChoices = [
    'Calm',
    'Grounded',
    'Anxious',
    'Energetic',
    'Reflective',
    'Low',
  ];

  final JournalEntry entry;
  final ValueChanged<String>? onPlace;
  final ValueChanged<String>? onMood;
  final Future<String?> Function() lookupCurrentPlace;

  static bool moodIsAssigned(String? mood) {
    final value = mood?.trim() ?? '';
    return value.isNotEmpty && value.toLowerCase() != 'neutral';
  }

  @override
  Widget build(BuildContext context) {
    final place = entry.display.locationLabel?.trim();
    final mood = entry.reflection.mood;
    final health = (entry.reflection.healthStateOfMind ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const Key('entry_context_placeholders'),
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              icon: Icons.place_outlined,
              label: (place == null || place.isEmpty) ? 'Place' : place,
              onTap: onPlace == null ? null : () => _pickPlace(context),
            ),
            _Chip(
              key: Key('entry_mood_${entry.id}'),
              icon: Icons.mood_outlined,
              label: moodIsAssigned(mood) ? mood.trim() : 'State of mind',
              onTap: onMood == null ? null : () => _pickMood(context),
            ),
            if (AppleHealthPlatform.isIos && health.isNotEmpty)
              HealthStateOfMindChip(label: health, entryId: entry.id),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          PrivacyScreenCopy.placeLookupDisclosure,
          key: const Key('place_lookup_disclosure'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _pickMood(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in moodChoices)
                ActionChip(
                  key: Key('mood_chip_$choice'),
                  label: Text(choice),
                  onPressed: () => Navigator.pop(context, choice),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) onMood?.call(chosen);
  }

  Future<void> _pickPlace(BuildContext context) async {
    final place = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) =>
          _PlaceSheet(lookupCurrentPlace: lookupCurrentPlace),
    );
    if (place != null && place.isNotEmpty) onPlace?.call(place);
  }
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.lookupCurrentPlace});

  final Future<String?> Function() lookupCurrentPlace;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  bool _busy = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _busy = true);
    try {
      final place = await widget.lookupCurrentPlace();
      if (!mounted) return;
      if (place == null || place.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't find this place.")),
        );
        setState(() => _busy = false);
        return;
      }
      Navigator.pop(context, place);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't find this place.")),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PrivacyScreenCopy.placeLookupDisclosure,
              key: const Key('place_sheet_lookup_disclosure'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('use_current_location'),
              onPressed: _busy ? null : _useCurrentLocation,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Use current location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

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
