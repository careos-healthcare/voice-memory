import 'dart:io';

import '../../features/curiosity_loop/infrastructure/clinical_telemetry_encrypted_storage.dart';
import '../../storage/encrypted_json_storage.dart';
import '../privacy/audio_vault_service.dart';
import '../security/biometric_vault_service.dart';
import 'core_services.dart';
import 'v1_composition_config.dart';

final class PrivacyServices {
  PrivacyServices._({
    required this.biometricVault,
    required this.audioVault,
    required this.clinicalTelemetryEncryptedStorage,
  });

  final BiometricVaultService? biometricVault;
  final AudioVaultService audioVault;
  final EncryptedJsonStorage clinicalTelemetryEncryptedStorage;

  static Future<PrivacyServices> create(
    CoreServices core,
    V1CompositionConfig config,
  ) async {
    BiometricVaultService? biometricVault;
    if (!config.testMode) {
      biometricVault = BiometricVaultService(
        store: PlatformBiometricVaultSecureStore(storage: core.secureStorage),
      );
      BiometricVaultService.install(biometricVault);
      await biometricVault.initialize();
      if (biometricVault.isEnabled && !await biometricVault.unlock()) {
        throw StateError(
          'The biometric vault must be unlocked before private storage opens.',
        );
      }
    }

    final audioVault = config.testMode
        ? AudioVaultService(
            keyStore: InMemoryAudioVaultKeyStore(),
            vaultDirectory: () async =>
                Directory('${config.basePath}/encrypted_audio_vault'),
            temporaryDirectory: () async =>
                Directory('${config.basePath}/audio_working'),
          )
        : AudioVaultService();
    final telemetry = config.testMode
        ? ClinicalTelemetryEncryptedStorage.forTest()
        : await ClinicalTelemetryEncryptedStorage.forSecureStorage(
            core.secureStorage,
          );
    return PrivacyServices._(
      biometricVault: biometricVault,
      audioVault: audioVault,
      clinicalTelemetryEncryptedStorage: telemetry,
    );
  }

  void lock() => biometricVault?.lock();
}
