import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// Resolves generated strings while keeping isolated widget harnesses usable.
///
/// Production surfaces always receive the generated delegate from
/// `ArchiveMeApp`; the English fallback is for embedders and focused tests that
/// intentionally render a leaf widget without the application shell.
AppLocalizations appLocalizationsOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(
        Localizations.maybeLocaleOf(context) ?? const Locale('en'),
      );
}
