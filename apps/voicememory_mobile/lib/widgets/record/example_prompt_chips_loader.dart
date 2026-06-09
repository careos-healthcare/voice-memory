import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../record/example_prompt_visibility.dart';
import '../../services/app_services.dart';
import 'example_prompt_chips.dart';

/// Loads journal state and renders [ExamplePromptChips] for empty / onboarding surfaces.
class ExamplePromptChipsLoader extends StatefulWidget {
  const ExamplePromptChipsLoader({
    super.key,
    required this.surface,
  });

  final String surface;

  @override
  State<ExamplePromptChipsLoader> createState() => _ExamplePromptChipsLoaderState();
}

class _ExamplePromptChipsLoaderState extends State<ExamplePromptChipsLoader> {
  int _recordingCount = 0;
  bool _firstArchiveMilestoneCompleted = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _recordingCount = all.length;
      _firstArchiveMilestoneCompleted =
          ExamplePromptVisibility.hasCompletedFirstArchiveMilestone(all);
      _loaded = true;
    });
  }

  void _onPromptSelected(String prompt) {
    final encoded = Uri.encodeComponent(prompt);
    context.go('/record?prompt=$encoded&autostart=1');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return ExamplePromptChips(
      recordingCount: _recordingCount,
      firstArchiveMilestoneCompleted: _firstArchiveMilestoneCompleted,
      onPromptSelected: _onPromptSelected,
      surface: widget.surface,
    );
  }
}
