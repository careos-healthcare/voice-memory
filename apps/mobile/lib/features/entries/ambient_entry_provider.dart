import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/ambient_context_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ambient capture used when a new entry is saved.
final ambientContextServiceProvider = Provider<AmbientContextService>(
  (ref) => AmbientContextService.shared,
);

/// Gathers surroundings and returns the entry to persist.
///
/// The capture future finishes within the service budget, including when a
/// permission is denied.
Future<JournalEntry> attachAmbientContext(JournalEntry entry) {
  return AmbientContextService.shared.attach(entry);
}
