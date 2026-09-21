import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';

class InsightsConversationTurn {
  const InsightsConversationTurn({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
  };
}

class InsightsConversationReply {
  const InsightsConversationReply({
    required this.reply,
    required this.citedEntryIds,
    required this.groundedness,
  });

  final String reply;
  final List<String> citedEntryIds;
  final String groundedness;
}

// ignore: one_member_abstracts — DI seam, same pattern as ArchiveSynthesisApiClient
abstract interface class InsightsConversationApiClient {
  Future<ApiResult<InsightsConversationReply>> sendConversationMessage({
    required List<InsightsConversationTurn> conversationHistory,
    required String message,
    NetworkCancelToken? cancelToken,
  });
}
