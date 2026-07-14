/// Gated Pro utility previews — not full expansion features.
abstract final class ProUtilityCopyFix {
  ProUtilityCopyFix._();

  static const previewLabel = 'Pro utility preview';

  static const historyPreview = 'See older proof over time.';
  static const exportPreview = 'Keep a copy of your archive.';
  static const reportPreview =
      'A private monthly summary could show what returned, changed, softened, and what to watch next.';

  static const plannedSuffix = '(planned preview — not live yet)';

  static Iterable<String> allVisibleStrings() sync* {
    yield previewLabel;
    yield historyPreview;
    yield exportPreview;
    yield reportPreview;
    yield plannedSuffix;
  }
}
