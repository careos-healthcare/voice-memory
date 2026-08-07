import '../models/curiosity_hook.dart';

/// Metadata extracted from a post-save voice moment for curiosity targeting.
class CuriosityHookEntryMetadata {
  const CuriosityHookEntryMetadata({
    required this.entryId,
    required this.createdAt,
    required this.extractedAnchors,
    this.emotionalTone,
    this.hasBlockers = false,
    this.entryCount = 1,
  });

  final String entryId;
  final DateTime createdAt;
  final List<String> extractedAnchors;
  final String? emotionalTone;
  final bool hasBlockers;
  final int entryCount;
}

abstract final class _CuriosityHookCopy {
  _CuriosityHookCopy._();

  static String blockerPrompt(String anchor) =>
      'Before "$anchor" showed up again, what got in the way?';

  static String momentumPrompt(String anchor) =>
      'You named "$anchor" — what felt different about it this time?';

  static String anchorFollowUpPrompt(String anchor) =>
      'Next time "$anchor" comes up, what do you want to notice first?';

  static String returnWatchPrompt(String anchor) =>
      'Come back when "$anchor" shows up again and say what changed.';
}

/// Builds targeted post-save curiosity hooks from entry metadata only.
abstract final class CuriosityHookEngine {
  CuriosityHookEngine._();

  static const _maxAnchorChars = 72;
  static const _maxRecentTypes = 4;

  static CuriosityHook? build({
    required CuriosityHookEntryMetadata metadata,
    Iterable<CuriosityHookType> recentHookTypes = const [],
    DateTime? now,
  }) {
    if (metadata.entryId.trim().isEmpty) return null;

    final anchor = _primaryAnchor(metadata.extractedAnchors);
    if (anchor == null) return null;

    final hookType = _selectHookType(
      metadata: metadata,
      recentHookTypes: recentHookTypes,
    );
    if (hookType == null) return null;

    final prompt = _promptFor(hookType: hookType, anchor: anchor);
    if (prompt.isEmpty) return null;

    final clock = now ?? DateTime.now().toUtc();
    return CuriosityHook(
      id: _hookId(metadata.entryId, clock),
      entryId: metadata.entryId,
      createdAt: metadata.createdAt.toUtc(),
      primaryAnchor: anchor,
      hookType: hookType,
      dynamicPrompt: prompt,
    );
  }

  static String? _primaryAnchor(List<String> extractedAnchors) {
    for (final raw in extractedAnchors) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length <= _maxAnchorChars) return trimmed;
      return '${trimmed.substring(0, _maxAnchorChars - 1).trim()}…';
    }
    return null;
  }

  static CuriosityHookType? _selectHookType({
    required CuriosityHookEntryMetadata metadata,
    required Iterable<CuriosityHookType> recentHookTypes,
  }) {
    final recent = recentHookTypes.take(_maxRecentTypes).toList();
    final candidates = <CuriosityHookType>[];

    if (metadata.hasBlockers) {
      candidates.add(CuriosityHookType.blocker);
    }
    if (_hasMomentumTone(metadata.emotionalTone) && !metadata.hasBlockers) {
      candidates.add(CuriosityHookType.momentum);
    }
    if (metadata.entryCount >= 3) {
      candidates.add(CuriosityHookType.returnWatch);
    }
    candidates.add(CuriosityHookType.anchorFollowUp);

    for (final candidate in candidates) {
      if (!_recentlyUsed(candidate, recent)) return candidate;
    }

    for (final candidate in candidates) {
      if (recent.isEmpty || recent.first != candidate) return candidate;
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  static bool _recentlyUsed(
    CuriosityHookType candidate,
    List<CuriosityHookType> recent,
  ) {
    if (recent.isEmpty) return false;
    if (recent.first == candidate) return true;
    if (recent.length >= 2 && recent[1] == candidate) return true;
    return false;
  }

  static bool _hasMomentumTone(String? emotionalTone) {
    final tone = emotionalTone?.trim().toLowerCase();
    if (tone == null || tone.isEmpty) return false;
    const momentumSignals = [
      'lighter',
      'lighter than',
      'hopeful',
      'calm',
      'relief',
      'clearer',
      'easier',
      'steady',
      'settled',
    ];
    return momentumSignals.any(tone.contains);
  }

  static String _promptFor({
    required CuriosityHookType hookType,
    required String anchor,
  }) {
    return switch (hookType) {
      CuriosityHookType.blocker => _CuriosityHookCopy.blockerPrompt(anchor),
      CuriosityHookType.momentum => _CuriosityHookCopy.momentumPrompt(anchor),
      CuriosityHookType.returnWatch => _CuriosityHookCopy.returnWatchPrompt(
        anchor,
      ),
      CuriosityHookType.anchorFollowUp =>
        _CuriosityHookCopy.anchorFollowUpPrompt(anchor),
    };
  }

  static String _hookId(String entryId, DateTime createdAt) =>
      'curiosity_${entryId}_${createdAt.millisecondsSinceEpoch}';
}
