/// Stable domain keys and the titles people actually see.
///
/// Storage, routes, and provider names keep [storageKey]. Only [displayTitle]
/// belongs in the interface.
enum ArchiveDomainKey {
  theories,
  factLedger,
  theoryRankingEngine,
  traitPollution,
}

extension ArchiveDomainDisplay on ArchiveDomainKey {
  String get storageKey => switch (this) {
    ArchiveDomainKey.theories => 'theories',
    ArchiveDomainKey.factLedger => 'fact_ledger',
    ArchiveDomainKey.theoryRankingEngine => 'theory_ranking_engine',
    ArchiveDomainKey.traitPollution => 'trait_pollution',
  };

  String get displayTitle => switch (this) {
    ArchiveDomainKey.theories => 'Life Patterns',
    ArchiveDomainKey.factLedger => 'Core Memory',
    ArchiveDomainKey.theoryRankingEngine => 'Key Themes',
    ArchiveDomainKey.traitPollution => 'Pattern Disambiguation',
  };
}
