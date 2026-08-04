import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../catalyst_models.dart';
import '../catalyst_store.dart';
import '../catalyst_templates.dart';
import '../catalyst_workflow_runner.dart';

typedef CatalystOwnerAuthorizer = Future<bool> Function(String reason);
typedef CatalystRecipeSaver = Future<void> Function(CatalystRecipe recipe);

final class CatalystStudioSheet extends StatefulWidget {
  const CatalystStudioSheet({
    super.key,
    required this.store,
    required this.runner,
    required this.authorizeOwner,
    this.initialState,
    this.saveRecipe,
    this.onOpenSandbox,
  });

  final CatalystStore store;
  final CatalystWorkflowRunner runner;
  final CatalystOwnerAuthorizer authorizeOwner;
  final CatalystState? initialState;
  final CatalystRecipeSaver? saveRecipe;
  final VoidCallback? onOpenSandbox;

  static Future<void> show(
    BuildContext context, {
    required CatalystStore store,
    required CatalystWorkflowRunner runner,
    required CatalystOwnerAuthorizer authorizeOwner,
    VoidCallback? onOpenSandbox,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'catalyst-studio',
    builder: (_) => CatalystStudioSheet(
      store: store,
      runner: runner,
      authorizeOwner: authorizeOwner,
      onOpenSandbox: onOpenSandbox,
    ),
  );

  @override
  State<CatalystStudioSheet> createState() => _CatalystStudioSheetState();
}

class _CatalystStudioSheetState extends State<CatalystStudioSheet> {
  CatalystState? _state;
  StreamSubscription<CatalystState>? _subscription;
  String? _status;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    if (_state == null) unawaited(_load());
    _subscription = widget.store.changes.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  Future<void> _load() async {
    final state = await widget.store.read();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _toggle(CatalystRecipe recipe, bool enabled) async {
    final updated = recipe.copyWith(enabled: enabled);
    setState(() {
      final state = _state;
      if (state == null) return;
      _state = state.copyWith(
        recipes: [
          for (final item in state.recipes)
            if (item.id == recipe.id) updated else item,
        ],
      );
    });
    await (widget.saveRecipe ?? widget.store.saveRecipe)(updated);
  }

  Future<void> _clone(CatalystRecipe template) async {
    final id =
        '${template.templateId}-${DateTime.now().microsecondsSinceEpoch}';
    await widget.store.saveRecipe(CatalystTemplates.clone(template, id));
    if (mounted) setState(() => _status = 'Recipe added locally.');
  }

  Future<void> _dryRun(CatalystRecipe recipe) async {
    final now = DateTime.now().toUtc();
    final event = CatalystEvent(
      id: 'dry:${now.microsecondsSinceEpoch}',
      kind: recipe.trigger.kind,
      occurredAt: now,
      payload: const {'manualDryRun': true},
    );
    final run = await widget.runner.execute(recipe, event, dryRun: true);
    await widget.store.appendRun(run);
    if (mounted) setState(() => _status = run.message);
  }

  Future<void> _approve(CatalystApproval approval) async {
    final approved = await widget.authorizeOwner(
      'Authorize the pending Catalyst action',
    );
    if (!approved) return;
    final run = await widget.runner.approve(approval.id);
    if (mounted) setState(() => _status = 'Action ${run.status.name}.');
  }

  Future<void> _changeTrigger(
    CatalystRecipe recipe,
    CatalystTriggerKind kind,
  ) => widget.store.saveRecipe(recipe.copyWith(trigger: CatalystTrigger(kind)));

  Future<void> _addAction(CatalystRecipe recipe, CatalystActionKind kind) =>
      widget.store.saveRecipe(
        recipe.copyWith(
          actions: [
            ...recipe.actions,
            CatalystAction(
              id: '${kind.name}-${DateTime.now().microsecondsSinceEpoch}',
              kind: kind,
              requiresOwnerApproval:
                  kind == CatalystActionKind.encryptedExport ||
                  kind == CatalystActionKind.vaultHygiene,
            ),
          ],
        ),
      );

  Future<void> _addCondition(CatalystRecipe recipe) async {
    final field = TextEditingController(text: 'source');
    final value = TextEditingController();
    var operator = CatalystConditionOperator.exists;
    final condition = await showDialog<CatalystCondition>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add condition'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('catalyst-condition-field'),
                controller: field,
                decoration: const InputDecoration(
                  labelText: 'Event field path',
                ),
              ),
              DropdownButtonFormField<CatalystConditionOperator>(
                initialValue: operator,
                decoration: const InputDecoration(labelText: 'Operator'),
                items: [
                  for (final item in CatalystConditionOperator.values)
                    DropdownMenuItem(value: item, child: Text(item.name)),
                ],
                onChanged: (next) {
                  if (next != null) setDialogState(() => operator = next);
                },
              ),
              if (operator != CatalystConditionOperator.exists)
                TextField(
                  key: const Key('catalyst-condition-value'),
                  controller: value,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('catalyst-condition-save'),
              onPressed: () {
                final path = field.text.trim();
                if (path.isEmpty) return;
                Navigator.pop(
                  context,
                  CatalystCondition(
                    field: path,
                    operator: operator,
                    value: operator == CatalystConditionOperator.exists
                        ? null
                        : _conditionValue(value.text),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    field.dispose();
    value.dispose();
    if (condition == null) return;
    await widget.store.saveRecipe(
      recipe.copyWith(conditions: [...recipe.conditions, condition]),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return SafeArea(
      top: false,
      child: Column(
        key: const Key('catalyst-studio-sheet'),
        children: [
          ListTile(
            title: const Text(
              'Catalyst Studio',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Air-gapped trigger, condition, and action workflows',
            ),
            trailing: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_status!, key: const Key('catalyst-status')),
            ),
          Expanded(
            child: state == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (widget.onOpenSandbox != null)
                        OutlinedButton.icon(
                          key: const Key('catalyst-open-sandbox'),
                          onPressed: widget.onOpenSandbox,
                          icon: const Icon(Icons.security_outlined),
                          label: const Text('Open Wasm Sandbox'),
                        ),
                      Text(
                        'Templates',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final template in CatalystTemplates.all)
                        Card(
                          key: Key('catalyst-template-${template.templateId}'),
                          child: ListTile(
                            leading: const Icon(Icons.auto_awesome),
                            title: Text(template.name),
                            subtitle: Text(
                              '${template.trigger.kind.name} → '
                              '${template.actions.length} action(s)',
                            ),
                            trailing: IconButton(
                              tooltip: 'Add recipe',
                              onPressed: () => _clone(template),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Active recipes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (state.recipes.isEmpty)
                        const Text('No recipes yet.')
                      else
                        for (final recipe in state.recipes)
                          _RecipeEditorCard(
                            recipe: recipe,
                            onToggle: (value) => _toggle(recipe, value),
                            onDryRun: () => _dryRun(recipe),
                            onTriggerChanged: (kind) =>
                                _changeTrigger(recipe, kind),
                            onActionAdded: (kind) => _addAction(recipe, kind),
                            onConditionAdded: () => _addCondition(recipe),
                          ),
                      if (state.approvals.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Owner approvals',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final approval in state.approvals)
                          ListTile(
                            key: Key('catalyst-approval-${approval.id}'),
                            title: Text('Recipe ${approval.recipeId}'),
                            subtitle: const Text(
                              'Sensitive local action is paused.',
                            ),
                            trailing: FilledButton(
                              onPressed: () => _approve(approval),
                              child: const Text('Review'),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Execution history',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${state.runs.length} runs • '
                        '${_averageMicros(state.runs)} µs average',
                        key: const Key('catalyst-runtime-metrics'),
                      ),
                      Card(
                        key: const Key('catalyst-execution-log'),
                        child: state.runs.isEmpty
                            ? const ListTile(title: Text('No runs yet.'))
                            : Column(
                                children: [
                                  for (final run in state.runs.reversed.take(
                                    20,
                                  ))
                                    ListTile(
                                      dense: true,
                                      title: Text(
                                        '${run.recipeId}: ${run.status.name}',
                                      ),
                                      subtitle: Text(
                                        run.message ??
                                            '${run.elapsedMicroseconds} µs',
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

final class _RecipeEditorCard extends StatelessWidget {
  const _RecipeEditorCard({
    required this.recipe,
    required this.onToggle,
    required this.onDryRun,
    required this.onTriggerChanged,
    required this.onActionAdded,
    required this.onConditionAdded,
  });

  final CatalystRecipe recipe;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDryRun;
  final ValueChanged<CatalystTriggerKind> onTriggerChanged;
  final ValueChanged<CatalystActionKind> onActionAdded;
  final VoidCallback onConditionAdded;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('catalyst-recipe-${recipe.id}'),
    child: ExpansionTile(
      title: Text(recipe.name),
      subtitle: Text(
        '${recipe.trigger.kind.name} • ${recipe.actions.length} actions',
      ),
      trailing: Switch(
        key: Key('catalyst-recipe-toggle-${recipe.id}'),
        value: recipe.enabled,
        onChanged: onToggle,
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        DropdownButtonFormField<CatalystTriggerKind>(
          key: Key('catalyst-trigger-${recipe.id}'),
          initialValue: recipe.trigger.kind,
          decoration: const InputDecoration(labelText: 'Trigger'),
          items: [
            for (final kind in CatalystTriggerKind.values)
              DropdownMenuItem(value: kind, child: Text(kind.name)),
          ],
          onChanged: (value) {
            if (value != null) onTriggerChanged(value);
          },
        ),
        const SizedBox(height: 8),
        for (final action in recipe.actions)
          Card(
            child: ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: Text(action.kind.name),
              subtitle: Text(
                action.requiresOwnerApproval
                    ? 'Owner approval required'
                    : 'Bounded local action',
              ),
            ),
          ),
        for (final condition in recipe.conditions)
          Card(
            child: ListTile(
              leading: const Icon(Icons.filter_alt_outlined),
              title: Text('${condition.field} ${condition.operator.name}'),
              subtitle: condition.value == null
                  ? null
                  : Text('${condition.value}'),
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              key: Key('catalyst-add-condition-${recipe.id}'),
              onPressed: onConditionAdded,
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Condition'),
            ),
            PopupMenuButton<CatalystActionKind>(
              key: Key('catalyst-add-action-${recipe.id}'),
              tooltip: 'Add action',
              onSelected: onActionAdded,
              itemBuilder: (_) => [
                for (final kind in CatalystActionKind.values)
                  PopupMenuItem(value: kind, child: Text(kind.name)),
              ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 4),
                    Text('Add action'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              key: Key('catalyst-dry-run-${recipe.id}'),
              onPressed: onDryRun,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Dry run'),
            ),
          ],
        ),
      ],
    ),
  );
}

Object? _conditionValue(String raw) {
  final value = raw.trim();
  if (value == 'true') return true;
  if (value == 'false') return false;
  return num.tryParse(value) ?? value;
}

int _averageMicros(List<CatalystRunLog> runs) {
  if (runs.isEmpty) return 0;
  return runs.fold<int>(0, (total, run) => total + run.elapsedMicroseconds) ~/
      runs.length;
}
