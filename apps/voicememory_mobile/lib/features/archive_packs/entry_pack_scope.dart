import 'package:flutter/foundation.dart';

import 'archive_pack.dart';

/// How the user wants to assign a pack for the next save.
enum EntryPackScope {
  noPack('no_pack'),
  existingPack('existing_pack'),
  newPack('new_pack');

  const EntryPackScope(this.id);

  final String id;

  String get label => switch (this) {
    EntryPackScope.noPack => ArchivePacksCopy.noPack,
    EntryPackScope.existingPack => ArchivePacksCopy.addToPack,
    EntryPackScope.newPack => ArchivePacksCopy.newPack,
  };
}

/// Session pack selection for the next save.
abstract class EntryPackScopeSession {
  EntryPackScopeSession._();

  static EntryPackScope selectedScope = EntryPackScope.noPack;
  static String? selectedPackId;
  static String? pendingNewPackName;
  static bool scopeExplicitlyChosen = false;

  static void selectScope(EntryPackScope scope) {
    selectedScope = scope;
    scopeExplicitlyChosen = true;
    if (scope != EntryPackScope.existingPack) {
      selectedPackId = null;
    }
    if (scope != EntryPackScope.newPack) {
      pendingNewPackName = null;
    }
  }

  static void selectExistingPack(String packId) {
    selectedScope = EntryPackScope.existingPack;
    selectedPackId = packId;
    scopeExplicitlyChosen = true;
  }

  static void setPendingNewPackName(String name) {
    pendingNewPackName = name.trim();
    selectedScope = EntryPackScope.newPack;
    scopeExplicitlyChosen = true;
  }

  static String? resolvePackIdForSave() {
    switch (selectedScope) {
      case EntryPackScope.noPack:
        return null;
      case EntryPackScope.existingPack:
        return selectedPackId;
      case EntryPackScope.newPack:
        return null;
    }
  }

  static void resetAfterSave() {
    selectedScope = EntryPackScope.noPack;
    selectedPackId = null;
    pendingNewPackName = null;
    scopeExplicitlyChosen = false;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    selectedScope = EntryPackScope.noPack;
    selectedPackId = null;
    pendingNewPackName = null;
    scopeExplicitlyChosen = false;
  }
}
