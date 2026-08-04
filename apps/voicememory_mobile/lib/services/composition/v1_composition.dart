import 'account_services.dart';
import 'analytics_services.dart';
import 'archive_services.dart';
import 'changes_services.dart';
import 'composition_registry.dart';
import 'core_services.dart';
import 'deferred_startup.dart';
import 'monetization_services.dart';
import 'privacy_services.dart';
import 'recording_services.dart';
import 'sync_services.dart';
import 'v1_composition_config.dart';

final class V1Composition {
  V1Composition._({
    required this.core,
    required this.account,
    required this.recording,
    required this.archive,
    required this.changes,
    required this.privacy,
    required this.monetization,
    required this.analytics,
    required this.sync,
    required this.registeredModules,
    required this.deferredStartup,
  });

  final CoreServices core;
  final AccountServices account;
  final RecordingServices recording;
  final ArchiveServices archive;
  final ChangesServices changes;
  final PrivacyServices privacy;
  final MonetizationServices monetization;
  final AnalyticsServices analytics;
  final SyncServices sync;
  final Set<String> registeredModules;

  /// Cold-start work Record does not need, held until after the first frame.
  final DeferredStartupCoordinator deferredStartup;

  static const Set<String> moduleNames = {
    'core',
    'account',
    'recording',
    'archive',
    'changes',
    'privacy',
    'monetization',
    'analytics',
    'sync',
  };

  static Future<V1Composition> create(V1CompositionConfig config) async {
    final registry = V1CompositionRegistry();
    final core = await registry.build(
      'core',
      () => CoreServices.create(config),
    );
    final privacy = await registry.build(
      'privacy',
      () => PrivacyServices.create(core, config),
    );
    final account = await registry.build(
      'account',
      () => AccountServices.create(core, config),
    );
    final archive = await registry.build(
      'archive',
      () => ArchiveServices.create(
        core,
        privacy,
        config,
        account.activeArchiveIdentity,
      ),
    );
    final recording = await registry.build(
      'recording',
      () => RecordingServices.create(core, privacy, archive, config),
    );
    final monetization = await registry.build(
      'monetization',
      () => MonetizationServices.create(core, config),
    );
    final changes = await registry.build(
      'changes',
      () => ChangesServices.create(core),
    );
    final analytics = await registry.build(
      'analytics',
      () => AnalyticsServices.create(config),
    );
    final sync = await registry.build(
      'sync',
      () => SyncServices.create(core, account, archive, config),
    );

    account.registerAccountScopedReset((identity) async {
      sync.pauseForAccountTransition();
      await recording.pauseForAccountTransition();
      await archive.activate(identity);
      await monetization.resetAccountScope(identity.authenticatedSubjectId);
      await sync.activateAccountScope(identity);
      recording.resumeAfterAccountTransition();
    });
    account.installAuthLifecycle();
    if (account.activeAccountId != null) {
      await account.resetAccountScope(account.activeAccountId);
    }
    final deferredStartup = DeferredStartupCoordinator()
      ..register(DeferredStartupStep.analyticsProvider, analytics.activate)
      ..register(DeferredStartupStep.monetization, monetization.activate)
      ..register(DeferredStartupStep.sync, sync.activate)
      ..register(
        DeferredStartupStep.archiveDerivedStores,
        archive.activateDerivedStores,
      );
    return V1Composition._(
      core: core,
      account: account,
      recording: recording,
      archive: archive,
      changes: changes,
      privacy: privacy,
      monetization: monetization,
      analytics: analytics,
      sync: sync,
      registeredModules: registry.registeredNames,
      deferredStartup: deferredStartup,
    );
  }

  Future<void> startForegroundOwnership() =>
      recording.startForegroundOwnership();

  /// Runs every deferred step. Intended for the first post-frame callback.
  Future<void> activateDeferredServices() => deferredStartup.runAll();

  Future<void> resetAccountScope(String? accountId) =>
      account.resetAccountScope(accountId);

  Future<void> dispose() async {
    await recording.dispose();
    await monetization.dispose();
    await archive.dispose();
    privacy.lock();
    core.dispose();
  }
}
