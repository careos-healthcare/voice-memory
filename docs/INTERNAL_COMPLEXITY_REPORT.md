# Internal Complexity Report

Internal Complexity Reduction v1 — founder tooling vs customer product.

_Generated 2026-05-30T18:11:41.983Z_

## Summary

| Metric | Value |
| --- | --- |
| Public routes | 50 |
| Internal routes | 42 |
| Internal : public ratio | 0.84 |
| **Internal Complexity Score** | **21** |
| Active KEEP panels | 21 |
| Target | < 25 active internal panels |
| Meets target | yes |

## Stale panel disposition

- **KEEP:** 21
- **MERGE:** 21
- **DELETE:** 21

## Unused panels (no events / usage / decisions)

- **MERGE** Theory curiosity engine — Fold into theory-discovery hub
- **MERGE** Evolving understanding — Duplicate on retention-discovery and theory-discovery
- **MERGE** Organic referral — Merged into retention-discovery hub
- **MERGE** Paywall attribution — Merged into retention-discovery hub
- **MERGE** Return trigger attribution — Merged into retention-discovery hub
- **MERGE** Archive attachment — Merged into retention-discovery hub
- **MERGE** Belief recall — Merged into retention-discovery hub
- **MERGE** Retention moat — Merged into retention-discovery hub
- **MERGE** Archive value progress — Superseded by archive progress unification
- **MERGE** Value moment paywall — Merged into retention-discovery hub
- **MERGE** Activation bottleneck — Merged into retention-discovery hub
- **MERGE** Blind spot quality — Fold into blind-spot-discovery
- **MERGE** Insight ingredient optimizer — Fold into blind-spot-discovery
- **MERGE** Blind spot experiment loop — Fold into blind-spot-discovery
- **MERGE** Breakthrough tracking — Fold into blind-spot-discovery
- **MERGE** Insight outcome — Fold into blind-spot-discovery
- **MERGE** Self-recognition ingredients — Fold into blind-spot-discovery
- **MERGE** Blind spot performance — Fold into blind-spot-discovery
- **MERGE** Surface primary — Fold into product-simplification report
- **DELETE** Archive simplicity — No events; superseded by product-simplification

## Panel registry

| Panel | Kind | Route | Disposition | Events | Usage | Decisions | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FounderTestPanel | founder_panel | /internal/founder-test | KEEP | yes | yes | yes |  |
| FounderReviewPanel | dashboard | /internal/founder-review | KEEP | yes | yes | yes |  |
| ProductSimplificationPanel | founder_panel | /internal/product-simplification | KEEP | no | yes | yes |  |
| ArchiveBeliefCenterPanel | founder_panel | /internal/founder-test | KEEP | no | yes | yes |  |
| ArchiveUnderstandingPanel | founder_panel | /internal/founder-test | KEEP | no | yes | yes |  |
| FounderEvolvingValidationPanel | founder_panel | /internal/founder-test | KEEP | yes | yes | yes |  |
| RetentionDiscoveryPanel | dashboard | /internal/retention-discovery | KEEP | yes | yes | yes |  |
| RetentionCoreDashboard | dashboard | /internal/retention-core | KEEP | yes | yes | yes |  |
| BlindSpotDiscoveryPanel | experiment_panel | /internal/blind-spot-discovery | KEEP | yes | yes | yes |  |
| EmotionalIntegrityPanel | dashboard | /internal/emotional-integrity | KEEP | no | yes | yes |  |
| OnboardingClarityDebugPanel | dashboard | /internal/onboarding-clarity | KEEP | yes | yes | yes |  |
| PerformanceHealthPanel | dashboard | /internal/performance-health | KEEP | yes | yes | yes |  |
| ArchiveReputationPanel | dashboard | /internal/archive-reputation | KEEP | no | yes | yes |  |
| TheoryDiscoveryPanel | experiment_panel | /internal/theory-discovery | KEEP | yes | yes | yes |  |
| ActivationMetricsPanel | dashboard | /internal/retention-discovery | KEEP | yes | yes | yes |  |
| ArchiveAsProductValidationPanel | founder_panel | /internal/archive-belief | KEEP | yes | yes | yes |  |
| ATierQualityDashboardPanel | dashboard | /internal/blind-spot-discovery | KEEP | yes | yes | yes |  |
| ArchiveVoiceConsistencyPanel | dashboard | /internal/archive-voice | KEEP | no | yes | yes |  |
| AuthValueValidationPanel | founder_panel | /internal/auth-value-validation | KEEP | yes | yes | yes |  |
| InsightScorecardInternalPanel | experiment_panel | /internal/blind-spot-discovery | KEEP | yes | yes | yes |  |
| ArchiveBeliefAdoptionPanel | founder_panel | /internal/archive-belief | KEEP | no | yes | yes |  |
| TheoryCuriosityEnginePanel | experiment_panel | /internal/theory-curiosity | MERGE | yes | no | no | Fold into theory-discovery hub |
| EvolvingUnderstandingPanel | experiment_panel | /internal/theory-discovery | MERGE | yes | yes | no | Duplicate on retention-discovery and theory-discovery |
| OrganicReferralPanel | dashboard | /internal/organic-referral | MERGE | yes | yes | no | Merged into retention-discovery hub |
| PaywallAttributionPanel | dashboard | /internal/paywall-attribution | MERGE | yes | yes | no | Merged into retention-discovery hub |
| ReturnTriggerPanel | dashboard | /internal/return-trigger-attribution | MERGE | yes | yes | no | Merged into retention-discovery hub |
| ArchiveAttachmentPanel | dashboard | /internal/archive-attachment | MERGE | yes | yes | no | Merged into retention-discovery hub |
| BeliefRecallPanel | experiment_panel | /internal/retention-discovery | MERGE | yes | no | no | Merged into retention-discovery hub |
| RetentionMoatPanel | dashboard | /internal/retention-discovery | MERGE | no | yes | no | Merged into retention-discovery hub |
| ArchiveValueProgressPanel | dashboard | /internal/retention-discovery | MERGE | no | yes | no | Superseded by archive progress unification |
| ValueMomentPaywallPanel | dashboard | /internal/retention-discovery | MERGE | yes | yes | no | Merged into retention-discovery hub |
| ActivationBottleneckPanel | dashboard | /internal/retention-discovery | MERGE | yes | yes | no | Merged into retention-discovery hub |
| BlindSpotQualityPanel | experiment_panel | /internal/blind-spot-discovery | MERGE | no | yes | no | Fold into blind-spot-discovery |
| InsightIngredientOptimizerPanel | experiment_panel | /internal/blind-spot-discovery | MERGE | no | no | no | Fold into blind-spot-discovery |
| BlindSpotExperimentLoopPanel | experiment_panel | /internal/blind-spot-discovery | MERGE | yes | no | no | Fold into blind-spot-discovery |
| BreakthroughTrackingPanel | experiment_panel | /internal/blind-spot-discovery | MERGE | yes | no | no | Fold into blind-spot-discovery |
| InsightOutcomePanel | experiment_panel | /internal/blind-spot-discovery | MERGE | yes | no | no | Fold into blind-spot-discovery |
| SelfRecognitionIngredientsPanel | experiment_panel | /internal/blind-spot-discovery | MERGE | no | no | no | Fold into blind-spot-discovery |
| BlindSpotPerformancePanel | experiment_panel | /internal/blind-spot-performance | MERGE | yes | yes | no | Fold into blind-spot-discovery |
| SurfacePrimaryPanel | dashboard | /internal/theory-discovery | MERGE | no | yes | no | Fold into product-simplification report |
| ArchiveSimplicityPanel | dashboard | /internal/archive-simplicity | DELETE | no | no | no | No events; superseded by product-simplification |
| ArchiveDivergencePanel | dashboard | /internal/archive-divergence | DELETE | no | no | no | No usage signals |
| ArchiveIndividualityPanel | dashboard | /internal/archive-individuality | DELETE | no | no | no | No usage signals |
| SacrednessReviewPanel | dashboard | /internal/sacredness-review | DELETE | no | no | no | No events; duplicate of emotional-integrity |
| DurabilityReviewPanel | dashboard | /internal/durability-review | DELETE | no | no | no | No usage signals |
| CallbackLearningDebugPanel | experiment_panel | /internal/callback-learning | DELETE | no | no | no | No events |
| BehaviorTruthPanel | dashboard | /internal/behavior-truth | DELETE | no | no | no | No usage signals |
| ReflectionFrictionPanel | dashboard | /internal/reflection-friction | DELETE | no | no | no | No usage signals |
| ResurfacingVarietyPanel | experiment_panel | /internal/resurfacing-variety | DELETE | no | no | no | No events |
| ResurfacingTimingDebugPanel | experiment_panel | /internal/resurfacing-timing | DELETE | no | no | no | No events |
| ResurfacingConfidenceDebugPanel | experiment_panel | /internal/resurfacing-confidence | DELETE | no | no | no | No events |
| SilenceIntelligenceDebugPanel | experiment_panel | /internal/silence-intelligence | DELETE | no | no | no | No events |
| FirstMagicMomentDebugPanel | experiment_panel | /internal/first-magic-moment | DELETE | no | no | no | No events |
| FirstWeekRetentionDebugPanel | dashboard | /internal/first-week-retention | DELETE | no | no | no | Superseded by retention-core |
| RecurrenceDensityDebugPanel | experiment_panel | /internal/recurrence-density | DELETE | no | no | no | No events |
| TranscriptCleanupDebugPanel | dashboard | /internal/transcript-cleanup | DELETE | no | no | no | No events |
| VulnerabilityTimingPanel | experiment_panel | /internal/vulnerability-timing | DELETE | no | no | no | No events |
| RememberedLaterPanel | dashboard | /internal/founder-review | DELETE | no | no | no | Fold into founder-review |
| ShareObservationPanel | dashboard | /internal/founder-review | DELETE | no | no | no | Fold into founder-review |
| FounderTestReportPanel | founder_panel | /internal/founder-test | MERGE | no | yes | no | Embedded in FounderTestPanel |
| ArchiveAsProductValidationPanel | founder_panel | /internal/founder-test | MERGE | yes | yes | yes | Duplicate route; use archive-belief entry |
| NotificationEffectivenessPanel | experiment_panel | — | DELETE | no | no | no | Unused panel file — no internal route |
| TheoryVolatilityPanel | experiment_panel | — | DELETE | no | no | no | Unused panel file — no internal route |

## Notes

- Set `FOUNDER_MODE=true` to expose `/internal/*` (still requires debug token or founder session).
- Customer product routes are audited separately in `lib/product/surface-audit.ts`.
