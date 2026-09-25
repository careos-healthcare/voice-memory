import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/data/network/insights_conversation_api_client.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sends pattern-exploration turns and keeps the running chat in memory.
class PatternExplorationConversationNotifier
    extends Notifier<PatternExplorationConversationState> {
  @override
  PatternExplorationConversationState build() =>
      const PatternExplorationConversationState();

  /// Appends [text] as a user turn, then asks the conversation API for a reply.
  ///
  /// Prior turns are sent as [InsightsConversationApiClient.sendConversationMessage]
  /// `conversationHistory`; [text] is the new `message`. On failure the user
  /// turn stays so they can send again.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final cloudSyncEnabled = await _cloudSyncEnabled();
    if (!cloudSyncEnabled) {
      state = state.copyWith(
        isSending: false,
        errorMessage: PatternExplorationConversationState.cloudLockedMessage,
      );
      return;
    }

    final history = [
      for (final message in state.messages)
        InsightsConversationTurn(role: message.role, content: message.content),
    ];

    state = state.copyWith(
      messages: [
        ...state.messages,
        PatternExplorationMessage(
          role: PatternExplorationMessage.roleUser,
          content: trimmed,
        ),
      ],
      isSending: true,
      clearError: true,
    );

    final result = await ref
        .read(insightsConversationApiClientProvider)
        .sendConversationMessage(
          conversationHistory: history,
          message: trimmed,
        );

    result.when(
      success: (reply) {
        state = state.copyWith(
          messages: [
            ...state.messages,
            PatternExplorationMessage(
              role: PatternExplorationMessage.roleAssistant,
              content: reply.reply,
              citedEntryIds: reply.citedEntryIds,
            ),
          ],
          isSending: false,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSending: false,
          errorMessage: failure.toUserMessage(),
        );
      },
    );
  }

  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = const PatternExplorationConversationState();
  }

  Future<bool> _cloudSyncEnabled() async {
    final override = UserPreferences.debugCloudSyncOverride;
    if (override != null) return override;
    if (!AppServices.isInitialized) return false;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    return preferences.isCloudSyncEnabled;
  }
}

final patternExplorationConversationProvider =
    NotifierProvider<
      PatternExplorationConversationNotifier,
      PatternExplorationConversationState
    >(PatternExplorationConversationNotifier.new);
