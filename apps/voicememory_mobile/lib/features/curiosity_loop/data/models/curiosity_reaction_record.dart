import '../../models/curiosity_hook.dart';
import '../../yesterdays_snapshot_reaction.dart';

/// One persisted reaction to a yesterday snapshot curiosity hook.
class CuriosityReactionRecord {
  const CuriosityReactionRecord({
    required this.id,
    required this.hookId,
    required this.timestamp,
    required this.reactionType,
    required this.primaryAnchor,
    required this.hookType,
  });

  final String id;
  final String hookId;
  final DateTime timestamp;
  final YesterdaysSnapshotReaction reactionType;
  final String primaryAnchor;
  final CuriosityHookType hookType;

  Map<String, dynamic> toJson() => {
    'id': id,
    'hookId': hookId,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'reactionType': reactionType.name,
    'primaryAnchor': primaryAnchor,
    'hookType': hookType.name,
  };

  static CuriosityReactionRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final id = json['id'] as String?;
    final hookId = json['hookId'] as String?;
    final primaryAnchor = json['primaryAnchor'] as String?;
    if (id == null ||
        id.isEmpty ||
        hookId == null ||
        hookId.isEmpty ||
        primaryAnchor == null ||
        primaryAnchor.trim().isEmpty) {
      return null;
    }
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
    if (timestamp == null) return null;
    final reactionType = _parseReactionType(json['reactionType'] as String?);
    if (reactionType == null) return null;
    final hookType = _parseHookType(json['hookType'] as String?);
    if (hookType == null) return null;
    return CuriosityReactionRecord(
      id: id,
      hookId: hookId,
      timestamp: timestamp,
      reactionType: reactionType,
      primaryAnchor: primaryAnchor.trim(),
      hookType: hookType,
    );
  }

  static YesterdaysSnapshotReaction? _parseReactionType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in YesterdaysSnapshotReaction.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  static CuriosityHookType? _parseHookType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in CuriosityHookType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
