import 'package:flutter/foundation.dart';

/// Handoff payload when opening pattern exploration from a saved entry.
@immutable
class ExplorePatternsSeed {
  const ExplorePatternsSeed({
    required this.entryId,
    required this.transcript,
  });

  final String entryId;
  final String transcript;
}

/// One turn in the pattern-exploration chat.
@immutable
class PatternExplorationMessage {
  const PatternExplorationMessage({
    required this.role,
    required this.content,
    this.citedEntryIds = const [],
  });

  static const roleUser = 'user';
  static const roleAssistant = 'assistant';

  final String role;
  final String content;

  /// Entry IDs cited by an assistant reply. Empty for user turns.
  final List<String> citedEntryIds;

  bool get isUser => role == roleUser;
  bool get isAssistant => role == roleAssistant;
}

/// In-memory conversation for the pattern-exploration notifier.
@immutable
class PatternExplorationConversationState {
  const PatternExplorationConversationState({
    this.messages = const [],
    this.isSending = false,
    this.errorMessage,
  });

  static const cloudLockedMessage =
      'Pattern exploration sends the question you type to the Thoughtprint '
      'app backend. The backend uses that question to read matching entries '
      'from your server-side fact ledger. Turn on Cloud Features to opt in '
      'before that request is sent.';

  final List<PatternExplorationMessage> messages;
  final bool isSending;
  final String? errorMessage;

  PatternExplorationConversationState copyWith({
    List<PatternExplorationMessage>? messages,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PatternExplorationConversationState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
