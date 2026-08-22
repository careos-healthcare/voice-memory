/// Privacy-safe share card copy — fixed lines only, never user transcript.
abstract final class ShareCardCopy {
  ShareCardCopy._();

  static const headline = 'ArchiveMe found a repeat';
  static const footer = 'Private by default';
  static const createShareCardCta = 'Create share card';

  static const confirmationTitle = 'Create private share card?';
  static const confirmationBody =
      'This image does not include your raw entries or audio.';
  static const createImageCta = 'Create image';
  static const cancelCta = 'Cancel';

  static const editLabelTitle = 'Edit display text';
  static const editLabelHelper =
      'Use words you are comfortable sharing. Raw entries stay private.';
  static const editLabelField = 'Pattern label';

  static const changeNoticedLine = '1 change noticed';

  static String relatedMoments(int count) {
    final n = count.clamp(1, 999);
    return '$n related ${n == 1 ? 'moment' : 'moments'}';
  }

  static Iterable<String> allVisibleCopy() sync* {
    yield headline;
    yield footer;
    yield createShareCardCta;
    yield confirmationTitle;
    yield confirmationBody;
    yield createImageCta;
    yield cancelCta;
    yield editLabelTitle;
    yield editLabelHelper;
    yield editLabelField;
    yield changeNoticedLine;
  }
}