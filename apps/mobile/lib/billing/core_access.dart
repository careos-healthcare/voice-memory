import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Recording, on-device transcription, playback, and saving stay available
/// without a subscription and without a usage counter.
///
/// Cloud encryption and pattern analysis stay behind their own feature
/// switches. Those switches are not minute, word, or entry quotas.
abstract final class CoreAccess {
  CoreAccess._();

  static const statement = ConsumerUiCopy.coreIsFreeForever;

  static bool get canRecord => true;

  static bool get canTranscribeLocally => true;

  static bool get canPlayBack => true;

  static bool get canSaveText => true;
}
