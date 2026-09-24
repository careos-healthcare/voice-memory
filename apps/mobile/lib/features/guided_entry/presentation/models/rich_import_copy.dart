/// User-facing copy for one-tap rich imports on a blank entry.
abstract final class RichImportCopy {
  static const notNow = 'Not now';
  static const continueLabel = 'Continue';
  static const draftSaved = 'Draft saved on this device.';

  static const addRecentPhoto = 'Add Recent Photo';
  static const attachLocation = 'Attach Location';
  static const logCurrentActivity = 'Log Current Activity';

  static const photoSoftTitle = 'Add your latest photo?';
  static const photoSoftBody =
      'ArchiveMe can attach the most recent photo in your library to a '
      'draft. The file stays on this device.';

  static const locationSoftTitle = 'Attach where you are?';
  static const locationSoftBody =
      'ArchiveMe can turn your current location into a neighborhood name '
      'for this draft. Coordinates stay on this device.';

  static const photosUnavailable =
      'Photo import stays off on this device. You can still write the '
      'moment yourself.';
  static const photosDenied =
      'Photo access was declined. Nothing was attached.';
  static const photosMissing = 'No recent photo was available to attach.';

  static const locationUnavailable =
      'Location stays off on this device. You can still write the moment '
      'yourself.';
  static const locationDenied =
      'Location access was declined. Nothing was attached.';
  static const locationMissing =
      'A neighborhood name was not available. Nothing was attached.';

  static const saveFailed = 'The draft could not be saved on this device.';
}
