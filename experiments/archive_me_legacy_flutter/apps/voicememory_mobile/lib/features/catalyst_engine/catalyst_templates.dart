import 'catalyst_models.dart';

abstract final class CatalystTemplates {
  static final morningCouncil = CatalystRecipe(
    id: 'template-morning-council',
    templateId: 'morning-council',
    name: 'Morning Council Dispatch',
    enabled: false,
    trigger: const CatalystTrigger(CatalystTriggerKind.firstUnlock),
    actions: const [
      CatalystAction(
        id: 'overnight-council',
        kind: CatalystActionKind.councilPrompt,
        arguments: {'scope': 'overnight'},
        timeout: Duration(seconds: 45),
      ),
    ],
  );

  static final orphanGuardian = CatalystRecipe(
    id: 'template-orphan-guardian',
    templateId: 'orphan-guardian',
    name: 'Orphan Guardian',
    enabled: false,
    trigger: const CatalystTrigger(
      CatalystTriggerKind.scheduleTick,
      configuration: {'intervalHours': 24},
    ),
    actions: const [
      CatalystAction(
        id: 'queue-orphans',
        kind: CatalystActionKind.queueOrphanBridge,
        arguments: {'olderThanDays': 7, 'maximum': 100},
      ),
      CatalystAction(
        id: 'cluster-orphans',
        kind: CatalystActionKind.rebuildClusters,
      ),
      CatalystAction(id: 'guarded-muse', kind: CatalystActionKind.museSweep),
    ],
  );

  static final vaultHygiene = CatalystRecipe(
    id: 'template-vault-hygiene',
    templateId: 'vault-hygiene',
    name: 'Vault Hygiene',
    enabled: false,
    trigger: const CatalystTrigger(
      CatalystTriggerKind.scheduleTick,
      configuration: {'intervalHours': 24},
    ),
    actions: const [
      CatalystAction(
        id: 'clean-old-audio',
        kind: CatalystActionKind.vaultHygiene,
        arguments: {'olderThanDays': 30},
        requiresOwnerApproval: true,
      ),
    ],
  );

  static List<CatalystRecipe> get all => [
    morningCouncil,
    orphanGuardian,
    vaultHygiene,
  ];

  static CatalystRecipe clone(CatalystRecipe template, String id) =>
      CatalystRecipe(
        id: id,
        name: template.name,
        templateId: template.templateId,
        trigger: template.trigger,
        conditions: template.conditions,
        actions: template.actions,
      );
}
