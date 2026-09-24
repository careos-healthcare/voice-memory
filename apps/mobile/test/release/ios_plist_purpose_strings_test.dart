import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('linked iOS plugins declare their purpose strings', () {
    final root = Directory.current.path.endsWith('apps/mobile')
        ? Directory.current
        : Directory('apps/mobile');
    final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
    final plist = File('${root.path}/ios/Runner/Info.plist').readAsStringSync();
    final purposes = _purposeStrings(plist);

    final required = <String, List<String>>{
      'health': [
        'NSHealthShareUsageDescription',
        'NSHealthUpdateUsageDescription',
      ],
      'device_calendar': ['NSCalendarsFullAccessUsageDescription'],
      'image_picker': [
        'NSPhotoLibraryUsageDescription',
        'NSCameraUsageDescription',
      ],
      'local_auth': ['NSFaceIDUsageDescription'],
      'record': ['NSMicrophoneUsageDescription'],
      'flutter_gemma_speech': ['NSSpeechRecognitionUsageDescription'],
    };

    for (final entry in required.entries) {
      if (!_dependsOn(pubspec, entry.key)) continue;
      for (final key in entry.value) {
        final value = purposes[key];
        expect(
          value,
          isNotNull,
          reason: '$entry.key links a protected API but $key is missing',
        );
        expect(value, isNotEmpty, reason: '$key is empty');
        expect(value, contains('Thoughtprint'), reason: '$key names the app');
      }
    }
  });
}

bool _dependsOn(String pubspec, String package) {
  return RegExp('^\\s+$package\\s*:', multiLine: true).hasMatch(pubspec);
}

Map<String, String> _purposeStrings(String plist) {
  final pairs = RegExp(
    r'<key>([^<]+)</key>\s*<string>([^<]*)</string>',
    multiLine: true,
  );
  return {for (final match in pairs.allMatches(plist)) match.group(1)!: match.group(2)!};
}
