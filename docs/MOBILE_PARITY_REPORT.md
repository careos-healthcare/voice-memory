# Mobile parity report

Generated: 2026-05-30T20:16:48.270Z

Archive feature parity for Flutter (`apps/voicememory_mobile`) vs web. Status is **evidence from repo structure**, not manual PASS flags.

| Feature | Status | Mobile surface | Notes |
| --- | --- | --- | --- |
| Belief | **COMPLETE** | /archive-belief | Belief header + living archive stack |
| Evidence | **COMPLETE** | EvidenceLockerCompact on /archive-belief | — |
| Timeline | **PARTIAL** | /updates + local timeline age | Simplified local timeline — not full web belief-change engine |
| Trust | **PARTIAL** | ArchiveReputationCardMobile | Local reputation heuristics — not full web trust graph |
| Reputation | **PARTIAL** | archive_reputation.dart | Mobile-local reputation score |
| Ownership | **COMPLETE** | /export + ProtectArchiveBanner | — |
| Survival | **PARTIAL** | /archive-tool/belief-survival | Drawer tool — simplified survival view |
| Accuracy | **PARTIAL** | /archive-tool/accuracy | Local accuracy signals from reputation |
| Contradictions | **PARTIAL** | /blind-spots | Simplified blind-spot review — not full web contradiction engine |
| Activity | **PARTIAL** | /discover (Changes tab) | Local theory diff — not full archive activity engine |
| Search | **PARTIAL** | /search | Route exists; not in tab bar — deferred v1.1 per parity plan |
| Export | **COMPLETE** | /export | — |
| Auth | **COMPLETE** | /account | — |
| Subscription | **PARTIAL** | /pricing → Stripe browser checkout | No RevenueCat — browser checkout + server entitlements; Add purchases_flutter for store-native primary platform |

## Summary

- Features: 5 complete, 9 partial, 0 missing
- v1 required archive features: none MISSING

Search is optional for v1 per `MOBILE_PARITY_PLAN.md`. Subscription **COMPLETE** requires native IAP + restore.
