import 'package:archiveme_mobile/features/memory/clean_slate_prompt_state.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/topic_shift_decision.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Session state for the clean-slate prompt — never persisted with content.
abstract class CleanSlatePromptStore {
  CleanSlatePromptStore._();

  static DateTime? _sessionStartedAt;
  static CleanSlateUserChoice? _userChoice;
  static var _dismissedForSession = false;

  static CleanSlateUserChoice? get userChoice => _userChoice;

  static bool get dismissedForSession => _dismissedForSession;

  static void noteSessionStart({DateTime? now}) {
    // Session timing always uses wall clock — engine `now` is for record replay only.
    _sessionStartedAt ??= DateTime.now();
  }

  static Duration sessionElapsed({DateTime? now}) {
    final started = _sessionStartedAt;
    if (started == null) return Duration.zero;
    return DateTime.now().difference(started);
  }

  static bool isWithinFirstMinute({DateTime? now}) =>
      sessionElapsed() < const Duration(seconds: 60);

  static void chooseUseArchiveContext({
    required int entryCount,
    String source = 'record',
    TopicShiftDecision? decision,
  }) {
    _userChoice = CleanSlateUserChoice.useArchiveContext;
    _trackChoice(
      ActivationFunnelAnalytics.topicShiftUseArchiveContext,
      entryCount: entryCount,
      source: source,
      decision: decision,
    );
  }

  static void chooseKeepSeparate({
    required int entryCount,
    String source = 'record',
    TopicShiftDecision? decision,
  }) {
    _userChoice = CleanSlateUserChoice.keepSeparate;
    _trackChoice(
      ActivationFunnelAnalytics.topicShiftKeepSeparate,
      entryCount: entryCount,
      source: source,
      decision: decision,
    );
  }

  static void chooseStartNewThread({
    required int entryCount,
    String source = 'record',
    TopicShiftDecision? decision,
  }) {
    _userChoice = CleanSlateUserChoice.startNewThread;
    _trackChoice(
      ActivationFunnelAnalytics.topicShiftStartNewThread,
      entryCount: entryCount,
      source: source,
      decision: decision,
    );
  }

  static void dismissForSession({
    required int entryCount,
    String source = 'record',
    TopicShiftDecision? decision,
  }) {
    _dismissedForSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.topicShiftPromptDismissed,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: source,
      decisionId: decision?.decisionId,
      reasonId: decision?.reasonId,
      suggestedAction: decision?.suggestedAction,
    );
  }

  static void notePromptSeen({
    required int entryCount,
    required TopicShiftDecision decision,
    String source = 'record',
  }) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.topicShiftPromptSeen,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: source,
      decisionId: decision.decisionId,
      reasonId: decision.reasonId,
      suggestedAction: decision.suggestedAction,
    );
  }

  static void resetAfterSave() {
    _userChoice = null;
    _dismissedForSession = false;
  }

  static bool allowsGovernance(TopicShiftDecision decision) {
    if (MemoryScopePolicy.scope == MemoryScope.off) return false;
    return switch (_userChoice) {
      CleanSlateUserChoice.useArchiveContext => true,
      CleanSlateUserChoice.keepSeparate => false,
      CleanSlateUserChoice.startNewThread => true,
      null when _dismissedForSession => true,
      null => !decision.shouldPrompt,
    };
  }

  static void _trackChoice(
    String event, {
    required int entryCount,
    required String source,
    TopicShiftDecision? decision,
  }) {
    ActivationFunnelAnalytics.track(
      event,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: source,
      decisionId: decision?.decisionId,
      reasonId: decision?.reasonId,
      suggestedAction: decision?.suggestedAction,
    );
  }

  static void resetSessionState() {
    _sessionStartedAt = null;
    _userChoice = null;
    _dismissedForSession = false;
  }

  @visibleForTesting
  static void resetSessionForTest() => resetSessionState();

  @visibleForTesting
  static void seedSessionStartForTest(DateTime startedAt) {
    _sessionStartedAt = startedAt;
  }
}