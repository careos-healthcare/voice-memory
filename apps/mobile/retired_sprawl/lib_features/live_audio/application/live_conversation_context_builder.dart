import 'package:archiveme_mobile/core/user/user_settings_store.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/live_audio/domain/live_conversational_persona.dart';

/// Loads citable ledger facts and user lens settings for live voice setup.
class LiveConversationContextBuilder {
  LiveConversationContextBuilder({
    required this._factLedgerStore,
    required this._userSettingsStore,
    this.recentEvidenceLimit = 8,
  });

  final FactLedgerStore _factLedgerStore;
  final UserSettingsStore _userSettingsStore;
  final int recentEvidenceLimit;

  Future<String> buildSystemInstruction() async {
    final facts = await _factLedgerStore.loadAll();
    final settings = await _userSettingsStore.load();

    final recentEvidence = facts
        .take(recentEvidenceLimit)
        .map(FactLedgerEntry.fromArchiveFact)
        .toList();

    return LiveConversationalPersona.buildSystemInstruction(
      recentEvidence: recentEvidence.isEmpty ? null : recentEvidence,
      activeLens: settings.activeLens,
    );
  }
}