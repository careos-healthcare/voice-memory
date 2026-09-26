import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/l10n/release_supported_locales.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release supportedLocales only include ARBs covering 95% of English', () {
    final root = Directory.current.path.endsWith('apps/mobile')
        ? Directory.current
        : Directory('apps/mobile');
    final enKeys = _messageKeys(File('${root.path}/lib/l10n/app_en.arb'));
    expect(enKeys, isNotEmpty);

    final thin = <String>[];
    for (final locale in archiveSupportedLocales(release: true)) {
      final arb = File('${root.path}/lib/l10n/app_${_arbSuffix(locale)}.arb');
      final keys = _messageKeys(arb);
      final covered = enKeys.where(keys.contains).length / enKeys.length;
      if (covered < 0.95) {
        thin.add('${locale.toLanguageTag()} ${(covered * 100).toStringAsFixed(1)}%');
      }
    }

    expect(
      thin,
      isEmpty,
      reason:
          'Release supportedLocales includes a catalog under 95% of '
          'app_en.arb: ${thin.join(', ')}',
    );
  });
}

Set<String> _messageKeys(File arb) {
  final decoded = jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final key in decoded.keys)
      if (!key.startsWith('@')) key,
  };
}

String _arbSuffix(Locale locale) {
  final script = locale.scriptCode;
  final country = locale.countryCode;
  return [
    locale.languageCode,
    if (script != null) script,
    if (country != null) country,
  ].join('_');
}
