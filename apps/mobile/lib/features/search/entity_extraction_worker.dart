import 'package:archiveme_mobile/storage/sqlite/migrations/migration_020_entity_graph.dart';
import 'package:sqflite/sqflite.dart';

/// One named thing pulled from a moment.
class ExtractedEntity {
  const ExtractedEntity({
    required this.name,
    required this.category,
    required this.description,
  });

  final String name;
  final String category;
  final String description;
}

/// A directed link between two extracted entities.
class ExtractedRelationship {
  const ExtractedRelationship({
    required this.source,
    required this.target,
    required this.relationType,
  });

  final ExtractedEntity source;
  final ExtractedEntity target;
  final String relationType;
}

/// Local structured extraction for one transcript.
class EntityExtractionDraft {
  const EntityExtractionDraft({
    required this.entities,
    required this.relationships,
  });

  final List<ExtractedEntity> entities;
  final List<ExtractedRelationship> relationships;
}

/// Finds people, locations, goals, and triggers without leaving the device.
abstract final class LocalEntityExtractor {
  static final _person = RegExp(
    r'\b(?:[Ww]ith|[Mm]et)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
  );
  static final _location = RegExp(
    r'\b(?:at|in)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
  );
  static final _goal = RegExp(
    r'\b(?:I want to|goal:?)\s+(.+?)(?=\s+when\b|\s+after\b|[.;]|$)',
    caseSensitive: false,
  );
  static final _trigger = RegExp(
    r'\b(?:when|after)\s+([^.;\n]+)',
    caseSensitive: false,
  );

  static EntityExtractionDraft extract(String transcript) {
    final people = _named(_person, transcript, EntityCategories.people);
    final locations = _named(
      _location,
      transcript,
      EntityCategories.locations,
    );
    final goals = _phrases(_goal, transcript, EntityCategories.goals);
    final triggers = _phrases(
      _trigger,
      transcript,
      EntityCategories.triggers,
    );
    final entities = [...people, ...locations, ...goals, ...triggers];
    return EntityExtractionDraft(
      entities: entities,
      relationships: _relationships(
        people: people,
        locations: locations,
        goals: goals,
        triggers: triggers,
        entities: entities,
      ),
    );
  }

  static List<ExtractedEntity> _named(
    RegExp pattern,
    String transcript,
    String category,
  ) {
    final found = <String, ExtractedEntity>{};
    for (final match in pattern.allMatches(transcript)) {
      final name = (match.group(1) ?? '').trim();
      if (name.isEmpty) continue;
      found.putIfAbsent(
        name.toLowerCase(),
        () => ExtractedEntity(
          name: name,
          category: category,
          description: name,
        ),
      );
    }
    return found.values.toList();
  }

  static List<ExtractedEntity> _phrases(
    RegExp pattern,
    String transcript,
    String category,
  ) {
    final found = <String, ExtractedEntity>{};
    for (final match in pattern.allMatches(transcript)) {
      final phrase = (match.group(1) ?? '').trim();
      if (phrase.length < 3) continue;
      found.putIfAbsent(
        phrase.toLowerCase(),
        () => ExtractedEntity(
          name: phrase,
          category: category,
          description: phrase,
        ),
      );
    }
    return found.values.toList();
  }

  static List<ExtractedRelationship> _relationships({
    required List<ExtractedEntity> people,
    required List<ExtractedEntity> locations,
    required List<ExtractedEntity> goals,
    required List<ExtractedEntity> triggers,
    required List<ExtractedEntity> entities,
  }) {
    final links = <ExtractedRelationship>[];
    final seen = <String>{};
    void add(ExtractedEntity source, ExtractedEntity target, String type) {
      final key = '$type:${source.category}:${source.name}:${target.name}';
      if (!seen.add(key)) return;
      links.add(
        ExtractedRelationship(
          source: source,
          target: target,
          relationType: type,
        ),
      );
    }

    for (final person in people) {
      for (final location in locations) {
        add(person, location, 'seen_at');
      }
    }
    for (final goal in goals) {
      for (final trigger in triggers) {
        add(goal, trigger, 'prompted_by');
      }
    }
    for (var i = 0; i < entities.length; i++) {
      for (var j = i + 1; j < entities.length; j++) {
        add(entities[i], entities[j], 'co_occurs');
      }
    }
    return links;
  }
}

/// Categories stored in the entities table.
abstract final class EntityCategories {
  static const people = 'people';
  static const locations = 'locations';
  static const goals = 'goals';
  static const triggers = 'triggers';
}

/// Result of writing one moment into the local graph.
class EntityExtractionResult {
  const EntityExtractionResult({
    required this.entryId,
    required this.entityIds,
    required this.relationshipIds,
  });

  final String entryId;
  final List<String> entityIds;
  final List<String> relationshipIds;
}

/// Upserts entities and grows relationship weights for new moments.
class EntityExtractionWorker {
  const EntityExtractionWorker({
    this.extract = LocalEntityExtractor.extract,
  });

  final EntityExtractionDraft Function(String transcript) extract;

  static const String entitiesTable = Migration020EntityGraph.entitiesTable;
  static const String relationshipsTable =
      Migration020EntityGraph.relationshipsTable;
  static const String entryEntitiesTable =
      Migration020EntityGraph.entryEntitiesTable;

  Future<EntityExtractionResult> processEntry({
    required DatabaseExecutor db,
    required String entryId,
    required String transcript,
    DateTime? seenAt,
  }) async {
    final draft = extract(transcript);
    final now = (seenAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final entityIds = <String>[];
    for (final entity in draft.entities) {
      entityIds.add(await _upsertEntity(db, entity: entity, seenAt: now));
    }
    for (final entityId in entityIds) {
      await db.insert(entryEntitiesTable, {
        'entry_id': entryId,
        'entity_id': entityId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final relationshipIds = <String>[];
    for (final link in draft.relationships) {
      relationshipIds.add(
        await _upsertRelationship(db, link: link, seenAt: now),
      );
    }
    return EntityExtractionResult(
      entryId: entryId,
      entityIds: entityIds,
      relationshipIds: relationshipIds,
    );
  }

  /// Processes moments that are not yet linked to any entity.
  Future<List<EntityExtractionResult>> processUnlinked(
    DatabaseExecutor db,
  ) async {
    final rows = await db.rawQuery('''
      SELECT id, transcript, created_at
      FROM journal_entries
      WHERE deleted_at IS NULL
        AND length(trim(transcript)) > 0
        AND id NOT IN (SELECT entry_id FROM $entryEntitiesTable)
      ORDER BY created_at ASC
    ''');
    final results = <EntityExtractionResult>[];
    for (final row in rows) {
      final entryId = row['id'] as String? ?? '';
      final transcript = row['transcript'] as String? ?? '';
      if (entryId.isEmpty || transcript.trim().isEmpty) continue;
      final createdAt = row['created_at'];
      final seenAt = createdAt is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true)
          : null;
      results.add(
        await processEntry(
          db: db,
          entryId: entryId,
          transcript: transcript,
          seenAt: seenAt,
        ),
      );
    }
    return results;
  }

  Future<String> _upsertEntity(
    DatabaseExecutor db, {
    required ExtractedEntity entity,
    required int seenAt,
  }) async {
    final id = entityStorageId(entity.category, entity.name);
    final existing = await db.query(
      entitiesTable,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(entitiesTable, {
        'id': id,
        'name': entity.name,
        'category': entity.category,
        'description': entity.description,
        'created_at': seenAt,
      });
    }
    return id;
  }

  Future<String> _upsertRelationship(
    DatabaseExecutor db, {
    required ExtractedRelationship link,
    required int seenAt,
  }) async {
    final sourceId = entityStorageId(link.source.category, link.source.name);
    final targetId = entityStorageId(link.target.category, link.target.name);
    final id = '${link.relationType}:$sourceId:$targetId';
    final existing = await db.query(
      relationshipsTable,
      columns: ['weight'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(relationshipsTable, {
        'id': id,
        'source_id': sourceId,
        'target_id': targetId,
        'relation_type': link.relationType,
        'weight': 1.0,
        'last_seen': seenAt,
      });
      return id;
    }
    final current = (existing.single['weight'] as num?)?.toDouble() ?? 0;
    await db.update(
      relationshipsTable,
      {'weight': current + 1, 'last_seen': seenAt},
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }
}

/// Stable primary key for an entity name inside a category.
String entityStorageId(String category, String name) {
  final slug = name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '$category:$slug';
}
