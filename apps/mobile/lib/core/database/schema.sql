-- Local knowledge graph for moments.
-- Entity rows are upserted by id. Relationship weight grows each time a pair
-- is seen together. entry_entities links a moment to the entities in it.

CREATE TABLE IF NOT EXISTS entities (
  id TEXT PRIMARY KEY,
  name TEXT,
  category TEXT,
  description TEXT,
  created_at INTEGER
);

CREATE TABLE IF NOT EXISTS relationships (
  id TEXT PRIMARY KEY,
  source_id TEXT,
  target_id TEXT,
  relation_type TEXT,
  weight REAL,
  last_seen INTEGER
);

CREATE TABLE IF NOT EXISTS entry_entities (
  entry_id TEXT,
  entity_id TEXT,
  PRIMARY KEY (entry_id, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_entities_category_name
  ON entities(category, name);

CREATE INDEX IF NOT EXISTS idx_relationships_source
  ON relationships(source_id);

CREATE INDEX IF NOT EXISTS idx_relationships_target
  ON relationships(target_id);

CREATE INDEX IF NOT EXISTS idx_entry_entities_entity
  ON entry_entities(entity_id);
