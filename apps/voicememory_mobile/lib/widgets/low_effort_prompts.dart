import 'package:flutter/material.dart';

import '../features/archive_prompt/archive_prompt_engine.dart';
import '../theme/app_theme.dart';

/// Up to 3 archive conversation starters — no scrolling wall.
class LowEffortPrompts extends StatefulWidget {
  const LowEffortPrompts({
    super.key,
    required this.promptSet,
    required this.onSelect,
  });

  final ArchivePromptSet promptSet;
  final ValueChanged<ArchivePrompt> onSelect;

  @override
  State<LowEffortPrompts> createState() => _LowEffortPromptsState();
}

class _LowEffortPromptsState extends State<LowEffortPrompts> {
  bool _expanded = false;
  int _refreshIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return TextButton(
        onPressed: () => setState(() => _expanded = true),
        child: const Text("I don't know what to talk about"),
      );
    }

    final visible = pickArchiveDisplayPrompts(
      widget.promptSet,
      refreshIndex: _refreshIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final prompt in visible)
              ActionChip(
                label: Text(
                  prompt.text,
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
                onPressed: () => widget.onSelect(prompt),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _refreshIndex += 1),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('New prompts'),
            ),
            TextButton(
              onPressed: () => setState(() => _expanded = false),
              child: const Text('Hide', style: TextStyle(color: AppTheme.muted)),
            ),
          ],
        ),
      ],
    );
  }
}
