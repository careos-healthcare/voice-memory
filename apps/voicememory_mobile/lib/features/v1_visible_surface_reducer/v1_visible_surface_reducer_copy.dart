/// V1 visible surface reducer copy — keep first-release journey small.
abstract final class V1VisibleSurfaceReducerCopy {
  V1VisibleSurfaceReducerCopy._();

  static const headline = 'Keep V1 small';

  static const body =
      'The first release should show only what helps the user save one repeat, '
      'understand the first proof, and see that Pro keeps the longer proof trail.';

  static const coreLine =
      'Core V1: save one repeat, first useful proof, confirm or correct, '
      'longer proof trail.';

  static const hiddenLine =
      'Hide dashboards, reports, action items, widgets, packs, analyst surfaces, '
      'search, and context expansion until they clearly support the proof trail.';

  static const guardrail =
      'Do not delete features. Keep non-core surfaces out of the first journey.';

  static const detailVisible = 'Visible in V1';
  static const detailHidden = 'Hidden for V1 first journey';
  static const detailGated = 'Gated until proof conditions pass';
  static const detailUserAsked = 'Visible only when user explicitly asks';
  static const detailDeveloper = 'Developer only';
  static const detailPostSave = 'Visible immediately after save';

  static String labelFor(V1Surface surface) => switch (surface) {
        V1Surface.recordCapture => 'Record capture',
        V1Surface.typeInstead => 'Type instead',
        V1Surface.promptAssist => 'Prompt assist',
        V1Surface.postSaveReinforcement => 'Post-save reinforcement',
        V1Surface.firstProof => 'First proof',
        V1Surface.whyProofAppeared => 'Why proof appeared',
        V1Surface.confirmCorrect => 'Confirm or correct',
        V1Surface.whatChanged => 'What changed',
        V1Surface.proLongerTrail => 'Pro longer proof trail',
        V1Surface.restorePurchases => 'Restore purchases',
        V1Surface.privacySupport => 'Privacy and support',
        V1Surface.archiveHome => 'Archive home',
        V1Surface.archiveHealth => 'Archive health',
        V1Surface.evidenceMap => 'Evidence map',
        V1Surface.reports => 'Reports',
        V1Surface.actionItems => 'Action items',
        V1Surface.archivePacks => 'Archive packs',
        V1Surface.archiveAnalyst => 'Archive analyst',
        V1Surface.widgets => 'Widgets',
        V1Surface.contextExpansion => 'Context expansion',
        V1Surface.dashboard => 'Dashboard',
        V1Surface.search => 'Search',
        V1Surface.monthlyReview => 'Monthly review',
        V1Surface.shareProof => 'Share proof',
        V1Surface.developerDiagnostics => 'Developer diagnostics',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield coreLine;
    yield hiddenLine;
    yield guardrail;
    yield detailVisible;
    yield detailHidden;
    yield detailGated;
    yield detailUserAsked;
    yield detailDeveloper;
    yield detailPostSave;
    for (final surface in V1Surface.values) {
      yield labelFor(surface);
    }
  }
}

enum V1Surface {
  recordCapture,
  typeInstead,
  promptAssist,
  postSaveReinforcement,
  firstProof,
  whyProofAppeared,
  confirmCorrect,
  whatChanged,
  proLongerTrail,
  restorePurchases,
  privacySupport,
  archiveHome,
  archiveHealth,
  evidenceMap,
  reports,
  actionItems,
  archivePacks,
  archiveAnalyst,
  widgets,
  contextExpansion,
  dashboard,
  search,
  monthlyReview,
  shareProof,
  developerDiagnostics,
}

enum V1SurfaceDecision {
  showCore,
  allowAfterProof,
  allowOnlyWhenUserAsked,
  hideForV1,
  developerOnly,
  releaseBlockerOnly,
}
