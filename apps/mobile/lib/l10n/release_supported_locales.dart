import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Locales a release build claims in the UI and on the store listing.
///
/// Incomplete catalogs (`app_es`, `app_hi`, `app_ms`, `app_ta`, `app_zh`,
/// `app_zh_Hans`) stay in `lib/l10n` for later translation work. Debug and
/// test builds can still load the generated delegates.
const List<Locale> releaseSupportedLocales = <Locale>[Locale('en')];

List<Locale> archiveSupportedLocales({bool? release}) {
  final shipping = release ?? kReleaseMode;
  if (shipping) return releaseSupportedLocales;
  return AppLocalizations.supportedLocales;
}
