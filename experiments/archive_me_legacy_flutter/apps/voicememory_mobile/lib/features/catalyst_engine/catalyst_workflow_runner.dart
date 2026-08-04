import 'dart:async';

import 'catalyst_models.dart';
import 'catalyst_store.dart';

typedef CatalystActionHandler =
    Future<String?> Function(Map<String, Object?> arguments);
typedef CatalystActionPreflight =
    Future<CatalystActionPreflightResult> Function(CatalystAction action);

final class CatalystActionPreflightResult {
  const CatalystActionPreflightResult({
    required this.available,
    required this.summary,
  });

  final bool available;
  final String summary;
}

final class CatalystActionBindings {
  const CatalystActionBindings({
    required this.tagNode,
    required this.rebuildClusters,
    required this.queueOrphanBridge,
    required this.councilPrompt,
    required this.encryptedExport,
    required this.museSweep,
    required this.vaultHygiene,
    this.sandboxModule,
    this.preflight,
  });

  final CatalystActionHandler tagNode;
  final CatalystActionHandler rebuildClusters;
  final CatalystActionHandler queueOrphanBridge;
  final CatalystActionHandler? councilPrompt;
  final CatalystActionHandler encryptedExport;
  final CatalystActionHandler museSweep;
  final CatalystActionHandler vaultHygiene;
  final CatalystActionHandler? sandboxModule;
  final CatalystActionPreflight? preflight;

  CatalystActionHandler? handler(CatalystActionKind kind) => switch (kind) {
    CatalystActionKind.tagNode => tagNode,
    CatalystActionKind.rebuildClusters => rebuildClusters,
    CatalystActionKind.queueOrphanBridge => queueOrphanBridge,
    CatalystActionKind.councilPrompt => councilPrompt,
    CatalystActionKind.encryptedExport => encryptedExport,
    CatalystActionKind.museSweep => museSweep,
    CatalystActionKind.vaultHygiene => vaultHygiene,
    CatalystActionKind.sandboxModule => sandboxModule,
  };
}

final class CatalystWorkflowRunner {
  CatalystWorkflowRunner({
    required this.store,
    required this.bindings,
    DateTime Function()? clock,
    this.workflowTimeout = const Duration(seconds: 90),
  }) : _clock = clock ?? DateTime.now;

  final CatalystStore store;
  final CatalystActionBindings bindings;
  final DateTime Function() _clock;
  final Duration workflowTimeout;
  final Set<String> _runningRecipes = {};
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<CatalystRunLog> execute(
    CatalystRecipe recipe,
    CatalystEvent event, {
    bool dryRun = false,
    int startActionIndex = 0,
    bool ownerApproved = false,
  }) async {
    final startedAt = _clock().toUtc();
    final watch = Stopwatch()..start();
    final runId = '${recipe.id}:${event.id}';
    if (_runningRecipes.contains(recipe.id)) {
      return _log(
        runId,
        recipe,
        event,
        CatalystRunStatus.failed,
        startedAt,
        watch,
        const [],
        'Recipe re-entry was blocked.',
      );
    }
    if (!_conditionsMatch(recipe.conditions, event.payload)) {
      return _log(
        runId,
        recipe,
        event,
        dryRun ? CatalystRunStatus.dryRun : CatalystRunStatus.succeeded,
        startedAt,
        watch,
        const [],
        'Conditions did not match.',
      );
    }
    _runningRecipes.add(recipe.id);
    _cancelled = false;
    final completed = <String>[];
    final outputs = <String>[];
    try {
      return await Future<CatalystRunLog>(() async {
        for (
          var index = startActionIndex;
          index < recipe.actions.length;
          index++
        ) {
          if (_cancelled) {
            return _log(
              runId,
              recipe,
              event,
              CatalystRunStatus.cancelled,
              startedAt,
              watch,
              completed,
              'Cancelled.',
            );
          }
          final action = recipe.actions[index];
          final preflight = bindings.preflight;
          if (preflight != null) {
            final check = await preflight(action);
            if (!check.available && !dryRun) {
              return _log(
                runId,
                recipe,
                event,
                CatalystRunStatus.capabilityUnavailable,
                startedAt,
                watch,
                completed,
                check.summary,
              );
            }
            if (dryRun && check.summary.isNotEmpty) outputs.add(check.summary);
          }
          final handler = bindings.handler(action.kind);
          if (handler == null) {
            return _log(
              runId,
              recipe,
              event,
              CatalystRunStatus.capabilityUnavailable,
              startedAt,
              watch,
              completed,
              '${action.kind.name} is unavailable on this device.',
            );
          }
          final sensitive =
              action.kind == CatalystActionKind.encryptedExport ||
              action.kind == CatalystActionKind.vaultHygiene;
          if ((action.requiresOwnerApproval || sensitive) &&
              !ownerApproved &&
              !dryRun) {
            final approval = CatalystApproval(
              id: '$runId:${action.id}',
              recipeId: recipe.id,
              event: event,
              actionIndex: index,
              createdAt: _clock(),
            );
            await store.update(
              (state) => state.copyWith(
                approvals: [
                  ...state.approvals.where((item) => item.id != approval.id),
                  approval,
                ],
              ),
            );
            return _log(
              runId,
              recipe,
              event,
              CatalystRunStatus.awaitingApproval,
              startedAt,
              watch,
              completed,
              'Owner approval is required for ${action.kind.name}.',
            );
          }
          if (dryRun) {
            completed.add(action.id);
            continue;
          }
          final arguments = <String, Object?>{
            ...action.arguments,
            'event': event.payload,
          };
          final output = await handler(arguments).timeout(action.timeout);
          completed.add(action.id);
          if (output != null && output.isNotEmpty) {
            outputs.add(
              output.substring(0, output.length.clamp(0, 4000).toInt()),
            );
          }
        }
        return _log(
          runId,
          recipe,
          event,
          dryRun ? CatalystRunStatus.dryRun : CatalystRunStatus.succeeded,
          startedAt,
          watch,
          completed,
          dryRun ? 'Dry run completed without mutations.' : null,
          output: outputs
              .join('\n')
              .substring(0, outputs.join('\n').length.clamp(0, 8000).toInt()),
        );
      }).timeout(workflowTimeout);
    } on UnsupportedError catch (error) {
      return _log(
        runId,
        recipe,
        event,
        CatalystRunStatus.capabilityUnavailable,
        startedAt,
        watch,
        completed,
        error.message?.toString() ?? 'Required local capability unavailable.',
      );
    } on TimeoutException {
      return _log(
        runId,
        recipe,
        event,
        CatalystRunStatus.timedOut,
        startedAt,
        watch,
        completed,
        'Workflow exceeded its time budget.',
      );
    } on Object catch (error) {
      return _log(
        runId,
        recipe,
        event,
        CatalystRunStatus.failed,
        startedAt,
        watch,
        completed,
        'Action failed: ${error.runtimeType}.',
      );
    } finally {
      _runningRecipes.remove(recipe.id);
    }
  }

  Future<CatalystRunLog> approve(String approvalId) async {
    final state = await store.read();
    final approval = state.approvals
        .where((item) => item.id == approvalId)
        .firstOrNull;
    if (approval == null) throw StateError('Catalyst approval not found.');
    final recipe = state.recipes
        .where((item) => item.id == approval.recipeId)
        .firstOrNull;
    if (recipe == null) throw StateError('Catalyst recipe not found.');
    await store.update(
      (current) => current.copyWith(
        approvals: current.approvals
            .where((item) => item.id != approvalId)
            .toList(),
      ),
    );
    final run = await execute(
      recipe,
      approval.event,
      startActionIndex: approval.actionIndex,
      ownerApproved: true,
    );
    await store.appendRun(run);
    return run;
  }

  bool _conditionsMatch(
    List<CatalystCondition> conditions,
    Map<String, Object?> payload,
  ) => conditions.every((condition) {
    final actual = _resolve(payload, condition.field);
    final expected = condition.value;
    return switch (condition.operator) {
      CatalystConditionOperator.equals => actual == expected,
      CatalystConditionOperator.notEquals => actual != expected,
      CatalystConditionOperator.exists => actual != null,
      CatalystConditionOperator.contains =>
        actual is String && expected is String && actual.contains(expected),
      CatalystConditionOperator.greaterThan =>
        actual is num && expected is num && actual > expected,
      CatalystConditionOperator.lessThan =>
        actual is num && expected is num && actual < expected,
    };
  });

  Object? _resolve(Map<String, Object?> value, String path) {
    Object? current = value;
    for (final segment in path.split('.')) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  CatalystRunLog _log(
    String id,
    CatalystRecipe recipe,
    CatalystEvent event,
    CatalystRunStatus status,
    DateTime startedAt,
    Stopwatch watch,
    List<String> completed,
    String? message, {
    String? output,
  }) => CatalystRunLog(
    id: id,
    recipeId: recipe.id,
    eventId: event.id,
    status: status,
    startedAt: startedAt,
    finishedAt: _clock(),
    completedActionIds: List.unmodifiable(completed),
    message: message,
    output: output,
    elapsedMicroseconds: watch.elapsedMicroseconds,
  );
}
