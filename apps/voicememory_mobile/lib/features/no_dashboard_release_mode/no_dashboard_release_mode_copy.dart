/// No dashboard release mode copy — keep V1 from feeling like a life dashboard.
abstract final class NoDashboardReleaseModeCopy {
  NoDashboardReleaseModeCopy._();

  static const headline = 'No dashboard release mode';

  static const body =
      'In release mode, hide dashboard surfaces unless the user explicitly asks '
      'or the surface directly supports first proof. Prefer proof trail language.';

  static const riskyLine =
      'Risky: archive health, action plan, evidence map, workspace quick actions, '
      'reports, dashboard, context insights, monthly review, archive analyst.';

  static const allowedLine =
      'Allowed: record, type instead, prompt assist, post-save reinforcement, '
      'first proof, why proof appeared, confirm/correct, what changed, Pro longer trail.';

  static const guardrail =
      'Do not call ArchiveMe a dashboard, command center, second brain, or life OS. '
      'No UI layout changes unless an existing policy hook allows it. No new features.';

  static const detailVisible = 'Visible in release mode';
  static const detailHidden = 'Hidden in release mode';
  static const detailUserAsked = 'Visible because user explicitly asked';
  static const detailProofGated = 'Gated until proof conditions pass';
  static const detailPostSave = 'Visible immediately after save';

  static const hardenedOkLine =
      'Release mode keeps dashboard surfaces hidden and proof trail surfaces allowed.';

  static const violatedLine =
      'Release mode is drifting toward dashboard positioning. Hide risky surfaces.';

  static String labelFor(NoDashboardReleaseSurface surface) => switch (surface) {
        NoDashboardReleaseSurface.record => 'Record',
        NoDashboardReleaseSurface.typeInstead => 'Type instead',
        NoDashboardReleaseSurface.promptAssist => 'Prompt assist',
        NoDashboardReleaseSurface.postSaveReinforcement =>
          'Post-save reinforcement',
        NoDashboardReleaseSurface.firstProof => 'First proof',
        NoDashboardReleaseSurface.whyProofAppeared => 'Why proof appeared',
        NoDashboardReleaseSurface.confirmCorrect => 'Confirm or correct',
        NoDashboardReleaseSurface.whatChanged => 'What changed',
        NoDashboardReleaseSurface.proLongerTrail => 'Pro longer trail',
        NoDashboardReleaseSurface.shareProof => 'Share proof',
        NoDashboardReleaseSurface.archiveHealth => 'Archive health',
        NoDashboardReleaseSurface.actionPlan => 'Action plan',
        NoDashboardReleaseSurface.evidenceMap => 'Evidence map',
        NoDashboardReleaseSurface.workspaceQuickActions =>
          'Workspace quick actions',
        NoDashboardReleaseSurface.reports => 'Reports',
        NoDashboardReleaseSurface.dashboard => 'Dashboard',
        NoDashboardReleaseSurface.contextInsights => 'Context insights',
        NoDashboardReleaseSurface.monthlyReview => 'Monthly review',
        NoDashboardReleaseSurface.archiveAnalyst => 'Archive analyst',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield riskyLine;
    yield allowedLine;
    yield guardrail;
    yield detailVisible;
    yield detailHidden;
    yield detailUserAsked;
    yield detailProofGated;
    yield detailPostSave;
    yield hardenedOkLine;
    yield violatedLine;
    for (final surface in NoDashboardReleaseSurface.values) {
      yield labelFor(surface);
    }
  }
}

enum NoDashboardReleaseSurface {
  record,
  typeInstead,
  promptAssist,
  postSaveReinforcement,
  firstProof,
  whyProofAppeared,
  confirmCorrect,
  whatChanged,
  proLongerTrail,
  shareProof,
  archiveHealth,
  actionPlan,
  evidenceMap,
  workspaceQuickActions,
  reports,
  dashboard,
  contextInsights,
  monthlyReview,
  archiveAnalyst,
}

enum NoDashboardReleaseModeDecision {
  hardened,
  violated,
}
