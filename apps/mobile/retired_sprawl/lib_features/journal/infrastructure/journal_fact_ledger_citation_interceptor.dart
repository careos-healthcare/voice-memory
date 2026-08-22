import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Indexes exact word citations into `fact_ledger` after each journal save.
class JournalFactLedgerCitationInterceptor implements JournalSaveInterceptor {
  const JournalFactLedgerCitationInterceptor();

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    await FactLedgerCitationService.indexEntry(entry);
  }
}
