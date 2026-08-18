# Drift ORM follow-up

## Completed in this migration

- `JournalEntries` drift table matching production `journal_entries` schema
- `JournalKeysetQueries` with typed keyset pagination via drift expressions
- FTS keyset pagination via `customSelect` with typed `Variable` parameters
- `WrappedSqfliteExecutor` to query the existing sqflite handle without duplicating connections

## Follow-up (FTS5 virtual tables)

FTS5 virtual tables (`memory_transcript_fts`) cannot be declared as standard drift tables.
Future work:

1. Add a drift include file documenting the FTS schema for reference
2. Migrate `countActive` / deprecated `fetchPage` FTS branches to `JournalKeysetQueries`
3. Consider drift `@TableIndex` on `journal_entries` for active-feed columns once the repository fully migrates off raw sqflite writes

## Full repository migration

Production writes (`upsertEntries`, FTS sync) still use sqflite transactions directly.
A full drift migration would:

- Move write paths to drift companions
- Register FTS virtual table via `@create` in a `.drift` file or `beforeOpen` custom statement
- Retire `WrappedSqfliteExecutor` in favor of a single drift-managed connection
