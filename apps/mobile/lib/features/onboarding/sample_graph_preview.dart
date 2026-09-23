import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';

/// One sample moment shown before an account exists.
class SampleMoment {
  const SampleMoment({required this.id, required this.text});

  final String id;
  final String text;
}

/// A sample moment ranked by a direct entity match or a one-hop neighbor.
class SampleGraphHit {
  const SampleGraphHit({
    required this.moment,
    required this.entityNames,
    required this.direct,
  });

  final SampleMoment moment;
  final List<String> entityNames;
  final bool direct;
}

/// Semantic preview over a fixed set of sample moments.
abstract final class SampleGraphPreview {
  static const moments = <SampleMoment>[
    SampleMoment(
      id: 'sample-ada',
      text: 'Met Ada at Harbor. I want to walk more when evenings get quiet.',
    ),
    SampleMoment(
      id: 'sample-sam',
      text: 'With Sam in Harbor. I want to write when mornings start slow.',
    ),
    SampleMoment(
      id: 'sample-ada-again',
      text: 'Met Ada after the meeting.',
    ),
  ];

  static List<SampleGraphHit> search(String query) {
    final drafts = {
      for (final moment in moments)
        moment.id: LocalEntityExtractor.extract(moment.text),
    };
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return [
        for (final moment in moments)
          SampleGraphHit(
            moment: moment,
            entityNames: _names(drafts[moment.id]!),
            direct: true,
          ),
      ];
    }

    final matched = <String>{};
    for (final draft in drafts.values) {
      for (final entity in draft.entities) {
        if (entity.name.toLowerCase().contains(needle)) {
          matched.add(entityStorageId(entity.category, entity.name));
        }
      }
    }
    if (matched.isEmpty) {
      return [
        for (final moment in moments)
          if (moment.text.toLowerCase().contains(needle))
            SampleGraphHit(
              moment: moment,
              entityNames: _names(drafts[moment.id]!),
              direct: true,
            ),
      ];
    }

    final neighbors = <String>{};
    for (final draft in drafts.values) {
      for (final link in draft.relationships) {
        final source = entityStorageId(link.source.category, link.source.name);
        final target = entityStorageId(link.target.category, link.target.name);
        if (matched.contains(source)) neighbors.add(target);
        if (matched.contains(target)) neighbors.add(source);
      }
    }
    final related = matched.union(neighbors);
    final hits = <SampleGraphHit>[];
    for (final moment in moments) {
      final draft = drafts[moment.id]!;
      final ids = {
        for (final entity in draft.entities)
          entityStorageId(entity.category, entity.name),
      };
      if (ids.intersection(related).isEmpty) continue;
      hits.add(
        SampleGraphHit(
          moment: moment,
          entityNames: _names(draft),
          direct: ids.intersection(matched).isNotEmpty,
        ),
      );
    }
    hits.sort((a, b) {
      if (a.direct != b.direct) return a.direct ? -1 : 1;
      return a.moment.id.compareTo(b.moment.id);
    });
    return hits;
  }

  static List<String> _names(EntityExtractionDraft draft) {
    return [for (final entity in draft.entities) entity.name];
  }
}
