/// Paywall value repair copy — beta/testing only, pre-paywall value framing.
abstract final class PaywallValueRepairCopy {
  PaywallValueRepairCopy._();

  static const title = 'Keep the evidence trail';
  static const body =
      'ArchiveMe just showed the first useful proof. Pro keeps the longer '
      'trail: what returns, what changes, what fades, and what you correct.';
  static const bulletKeepTracking = 'Keep tracking this pattern';
  static const bulletSeeChanges = 'See what changes over time';
  static const bulletCorrect = 'Correct anything that feels wrong';
  static const support = 'Not more chat. The record behind the pattern.';
  static const primaryCta = 'See Pro timeline';
  static const secondaryCta = 'Not now';

  static const List<String> bullets = [bulletKeepTracking, bulletSeeChanges, bulletCorrect];

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield bulletKeepTracking;
    yield bulletSeeChanges;
    yield bulletCorrect;
    yield support;
    yield primaryCta;
    yield secondaryCta;
  }
}