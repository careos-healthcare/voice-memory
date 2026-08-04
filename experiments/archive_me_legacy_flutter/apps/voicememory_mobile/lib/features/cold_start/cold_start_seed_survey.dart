import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_catalog.dart';
import '../../services/app_services.dart';
import 'cold_start_engine.dart';

class ColdStartSeedSurvey extends StatefulWidget {
  const ColdStartSeedSurvey({
    super.key,
    this.engine,
    this.persistData,
    this.onComplete,
    this.onSkip,
  });

  static const route = RouteCatalog.optionalContext;

  final ColdStartEngine? engine;
  final Future<void> Function(ColdStartSeedData data)? persistData;
  final ValueChanged<ColdStartSeedData>? onComplete;
  final VoidCallback? onSkip;

  @override
  State<ColdStartSeedSurvey> createState() => _ColdStartSeedSurveyState();
}

class _ColdStartSeedSurveyState extends State<ColdStartSeedSurvey> {
  final _people = TextEditingController();
  final _goal = TextEditingController();
  ColdStartFocus? _focus;
  var _saving = false;

  @override
  void dispose() {
    _people.dispose();
    _goal.dispose();
    super.dispose();
  }

  List<String> get _peopleNames => _people.text
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(2)
      .toList();

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    final data = ColdStartSeedData(
      people: _peopleNames,
      focus: _focus,
      goalOrChallenge: _goal.text.trim(),
    );
    try {
      if (widget.persistData case final persist?) {
        await persist(data);
      } else {
        final engine =
            widget.engine ??
            ColdStartEngine(
              seedStore: ColdStartSeedStore(AppServices.instance.prefs),
              graphStore: AppServices.instance.personalKnowledgeGraphStore,
            );
        await engine.persist(data);
      }
      if (!mounted) return;
      widget.onComplete?.call(data);
      if (widget.onComplete == null) _leave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _leave() {
    if (widget.onSkip case final onSkip?) {
      onSkip();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(RouteCatalog.recordHome);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Add personal context'),
      actions: [
        TextButton(
          key: const Key('cold_start_seed_skip'),
          onPressed: _saving ? null : _leave,
          child: const Text('Not now'),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'A little context can help future comparisons, but it is never required.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(
            'Who matters in your world right now?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cold_start_people_input'),
            controller: _people,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Names (optional)',
              hintText: 'Alex, Sam',
              helperText: 'Add up to two names, separated by commas.',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'What is your main focus this month?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final focus in ColdStartFocus.values)
                ChoiceChip(
                  key: Key('cold_start_focus_${focus.name}'),
                  selected: _focus == focus,
                  label: Text(
                    '${focus.name[0].toUpperCase()}${focus.name.substring(1)}',
                  ),
                  onSelected: (selected) =>
                      setState(() => _focus = selected ? focus : null),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'What goal or challenge are you navigating?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cold_start_goal_input'),
            controller: _goal,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'For example: create healthier boundaries at work',
              helperText: 'Optional',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('cold_start_seed_continue'),
            onPressed: _saving ? null : () => unawaited(_complete()),
            child: const Text('Save optional context'),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('cold_start_seed_skip_bottom'),
            onPressed: _saving ? null : _leave,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    ),
  );
}
