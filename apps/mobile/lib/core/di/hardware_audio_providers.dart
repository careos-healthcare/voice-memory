import 'dart:io';

import 'package:archiveme_mobile/audio/hardware_audio_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the platform-specific audio hardware configuration at runtime.
final hardwareAudioConfigProvider = Provider<HardwareAudioConfig>((ref) {
  if (Platform.isIOS) return const IOSAudioConfig();
  if (Platform.isAndroid) return const AndroidAudioConfig();
  return const AndroidAudioConfig();
});
