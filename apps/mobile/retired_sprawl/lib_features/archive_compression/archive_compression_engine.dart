import 'package:archiveme_mobile/features/archive_compression/archive_compression_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';

const _maxGroups = 20;
const _minGroupSize = 3;
const _similarMomentsTitle = 'Similar moments';

/// Groups similar key moments so the archive stays clean as it grows.
///
/// Never auto-hides and never deletes underlying moments.
List<ArchiveMomentGroup> buildArchiveMomentGroups(List<KeyMoment> moments) {
  if (moments.length < _minGroupSize) return const [];

  final usedIds = <String>{};
  final groups = <ArchiveMomentGroup>[];

  // 1. Group by shared non-empty pattern title.
  final byPattern = <String, List<KeyMoment>>{};
  for (final moment in moments) {
    final title = moment.patternTitle?.trim() ?? '';
    if (title.isEmpty) continue;
    byPattern.putIfAbsent(title, () => []).add(moment);
  }

  for (final entry in byPattern.entries) {
    if (entry.value.length < _minGroupSize) continue;
    final group = _buildGroup(
      moments: entry.value,
      patternTitle: entry.key,
      suggestedAction: ArchiveCompressionSuggestedAction.keepTogether,
    );
    groups.add(group);
    usedIds.addAll(entry.value.map((m) => m.id));
  }

  // 2. Tag clusters for moments without a pattern title.
  final tagPool = moments
      .where(
        (m) =>
            !usedIds.contains(m.id) &&
            (m.patternTitle == null || m.patternTitle!.trim().isEmpty) &&
            m.tags.isNotEmpty,
      )
      .toList();

  for (final seed in tagPool) {
    if (usedIds.contains(seed.id)) continue;
    final cluster = _growTagCluster(seed, tagPool, usedIds);
    if (cluster.length < _minGroupSize) continue;

    final action = _suggestedActionForTagCluster(cluster);
    groups.add(
      _buildGroup(
        moments: cluster,
        patternTitle: null,
        suggestedAction: action,
      ),
    );
    usedIds.addAll(cluster.map((m) => m.id));
  }

  groups.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return b.lastDate.compareTo(a.lastDate);
  });

  return groups.take(_maxGroups).toList();
}

List<KeyMoment> _growTagCluster(
  KeyMoment seed,
  List<KeyMoment> pool,
  Set<String> usedIds,
) {
  final cluster = <KeyMoment>[seed];
  usedIds.add(seed.id);
  var changed = true;
  while (changed) {
    changed = false;
    for (final candidate in pool) {
      if (usedIds.contains(candidate.id)) continue;
      final overlaps = cluster.any(
        (member) => _sharedTagCount(member.tags, candidate.tags) >= 2,
      );
      if (overlaps) {
        cluster.add(candidate);
        usedIds.add(candidate.id);
        changed = true;
      }
    }
  }
  return cluster;
}

ArchiveCompressionSuggestedAction _suggestedActionForTagCluster(
  List<KeyMoment> cluster,
) {
  if (_hasMixedTitles(cluster) || _hasBroadMixedTags(cluster)) {
    return ArchiveCompressionSuggestedAction.split;
  }
  return ArchiveCompressionSuggestedAction.review;
}

bool _hasMixedTitles(List<KeyMoment> moments) {
  final titles = moments
      .map((m) => m.title.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet();
  return titles.length > 1;
}

bool _hasBroadMixedTags(List<KeyMoment> moments) {
  final union = moments.expand((m) => m.tags).toSet();
  final shared = _tagsSharedByAll(moments);
  if (shared.length >= 3) return false;
  return union.length > shared.length + 3;
}

Set<String> _tagsSharedByAll(List<KeyMoment> moments) {
  if (moments.isEmpty) return {};
  var shared = moments.first.tags.toSet();
  for (final m in moments.skip(1)) {
    shared = shared.intersection(m.tags.toSet());
  }
  return shared;
}

int _sharedTagCount(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final setB = b.toSet();
  return a.where(setB.contains).length;
}

ArchiveMomentGroup _buildGroup({
  required List<KeyMoment> moments,
  required String? patternTitle,
  required ArchiveCompressionSuggestedAction suggestedAction,
}) {
  moments.sort((a, b) => a.date.compareTo(b.date));
  final ids = moments.map((m) => m.id).toList();
  final tagCounts = <String, int>{};
  for (final m in moments) {
    for (final tag in m.tags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }
  final tags =
      tagCounts.entries.where((e) => e.value >= 2).map((e) => e.key).toList()
        ..sort();

  final title = patternTitle?.trim().isNotEmpty == true
      ? patternTitle!.trim()
      : _similarMomentsTitle;

  return ArchiveMomentGroup(
    id: _groupId(patternTitle: patternTitle, momentIds: ids),
    title: title,
    momentIds: ids,
    patternTitle: patternTitle?.trim().isNotEmpty == true
        ? patternTitle!.trim()
        : null,
    tags: tags,
    firstDate: moments.first.date,
    lastDate: moments.last.date,
    count: moments.length,
    suggestedAction: suggestedAction,
  );
}

String _groupId({
  required String? patternTitle,
  required List<String> momentIds,
}) {
  if (patternTitle != null && patternTitle.trim().isNotEmpty) {
    return 'grp_pattern_${patternTitle.trim().hashCode}';
  }
  final sorted = [...momentIds]..sort();
  return 'grp_tags_${sorted.join('_').hashCode}';
}