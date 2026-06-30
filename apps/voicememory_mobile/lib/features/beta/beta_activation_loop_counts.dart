/// Local counters for the first-three-entry activation loop — counts only.
class BetaActivationLoopCounts {
  const BetaActivationLoopCounts({
    this.appOpened = 0,
    this.recordScreenSeen = 0,
    this.firstMomentSaved = 0,
    this.oneEntryReturnScreenSeen = 0,
    this.secondMomentSaved = 0,
    this.twoEntryRelatedSeen = 0,
    this.twoEntryUnrelatedSeen = 0,
    this.thirdMomentSaved = 0,
    this.confirmedRepeatSeen = 0,
    this.paywallSeen = 0,
    this.restoreTapped = 0,
    this.purchaseTapped = 0,
  });

  final int appOpened;
  final int recordScreenSeen;
  final int firstMomentSaved;
  final int oneEntryReturnScreenSeen;
  final int secondMomentSaved;
  final int twoEntryRelatedSeen;
  final int twoEntryUnrelatedSeen;
  final int thirdMomentSaved;
  final int confirmedRepeatSeen;
  final int paywallSeen;
  final int restoreTapped;
  final int purchaseTapped;

  static const fieldLabels = <String, String>{
    'appOpened': 'App opened',
    'recordScreenSeen': 'Record screen seen',
    'firstMomentSaved': 'First moment saved',
    'oneEntryReturnScreenSeen': 'One-entry return screen seen',
    'secondMomentSaved': 'Second moment saved',
    'twoEntryRelatedSeen': 'Two-entry related state seen',
    'twoEntryUnrelatedSeen': 'Two-entry unrelated state seen',
    'thirdMomentSaved': 'Third moment saved',
    'confirmedRepeatSeen': 'Confirmed repeat seen',
    'paywallSeen': 'Paywall seen',
    'restoreTapped': 'Restore tapped',
    'purchaseTapped': 'Purchase tapped',
  };

  int valueForField(String field) {
    switch (field) {
      case 'appOpened':
        return appOpened;
      case 'recordScreenSeen':
        return recordScreenSeen;
      case 'firstMomentSaved':
        return firstMomentSaved;
      case 'oneEntryReturnScreenSeen':
        return oneEntryReturnScreenSeen;
      case 'secondMomentSaved':
        return secondMomentSaved;
      case 'twoEntryRelatedSeen':
        return twoEntryRelatedSeen;
      case 'twoEntryUnrelatedSeen':
        return twoEntryUnrelatedSeen;
      case 'thirdMomentSaved':
        return thirdMomentSaved;
      case 'confirmedRepeatSeen':
        return confirmedRepeatSeen;
      case 'paywallSeen':
        return paywallSeen;
      case 'restoreTapped':
        return restoreTapped;
      case 'purchaseTapped':
        return purchaseTapped;
      default:
        return 0;
    }
  }

  BetaActivationLoopCounts copyWithIncrement(String field) {
    switch (field) {
      case 'appOpened':
        return copyWith(appOpened: appOpened + 1);
      case 'recordScreenSeen':
        return copyWith(recordScreenSeen: recordScreenSeen + 1);
      case 'firstMomentSaved':
        return copyWith(firstMomentSaved: firstMomentSaved + 1);
      case 'oneEntryReturnScreenSeen':
        return copyWith(oneEntryReturnScreenSeen: oneEntryReturnScreenSeen + 1);
      case 'secondMomentSaved':
        return copyWith(secondMomentSaved: secondMomentSaved + 1);
      case 'twoEntryRelatedSeen':
        return copyWith(twoEntryRelatedSeen: twoEntryRelatedSeen + 1);
      case 'twoEntryUnrelatedSeen':
        return copyWith(twoEntryUnrelatedSeen: twoEntryUnrelatedSeen + 1);
      case 'thirdMomentSaved':
        return copyWith(thirdMomentSaved: thirdMomentSaved + 1);
      case 'confirmedRepeatSeen':
        return copyWith(confirmedRepeatSeen: confirmedRepeatSeen + 1);
      case 'paywallSeen':
        return copyWith(paywallSeen: paywallSeen + 1);
      case 'restoreTapped':
        return copyWith(restoreTapped: restoreTapped + 1);
      case 'purchaseTapped':
        return copyWith(purchaseTapped: purchaseTapped + 1);
      default:
        return this;
    }
  }

  BetaActivationLoopCounts copyWith({
    int? appOpened,
    int? recordScreenSeen,
    int? firstMomentSaved,
    int? oneEntryReturnScreenSeen,
    int? secondMomentSaved,
    int? twoEntryRelatedSeen,
    int? twoEntryUnrelatedSeen,
    int? thirdMomentSaved,
    int? confirmedRepeatSeen,
    int? paywallSeen,
    int? restoreTapped,
    int? purchaseTapped,
  }) {
    return BetaActivationLoopCounts(
      appOpened: appOpened ?? this.appOpened,
      recordScreenSeen: recordScreenSeen ?? this.recordScreenSeen,
      firstMomentSaved: firstMomentSaved ?? this.firstMomentSaved,
      oneEntryReturnScreenSeen:
          oneEntryReturnScreenSeen ?? this.oneEntryReturnScreenSeen,
      secondMomentSaved: secondMomentSaved ?? this.secondMomentSaved,
      twoEntryRelatedSeen: twoEntryRelatedSeen ?? this.twoEntryRelatedSeen,
      twoEntryUnrelatedSeen:
          twoEntryUnrelatedSeen ?? this.twoEntryUnrelatedSeen,
      thirdMomentSaved: thirdMomentSaved ?? this.thirdMomentSaved,
      confirmedRepeatSeen: confirmedRepeatSeen ?? this.confirmedRepeatSeen,
      paywallSeen: paywallSeen ?? this.paywallSeen,
      restoreTapped: restoreTapped ?? this.restoreTapped,
      purchaseTapped: purchaseTapped ?? this.purchaseTapped,
    );
  }

  Map<String, dynamic> toMap() => {
        'appOpened': appOpened,
        'recordScreenSeen': recordScreenSeen,
        'firstMomentSaved': firstMomentSaved,
        'oneEntryReturnScreenSeen': oneEntryReturnScreenSeen,
        'secondMomentSaved': secondMomentSaved,
        'twoEntryRelatedSeen': twoEntryRelatedSeen,
        'twoEntryUnrelatedSeen': twoEntryUnrelatedSeen,
        'thirdMomentSaved': thirdMomentSaved,
        'confirmedRepeatSeen': confirmedRepeatSeen,
        'paywallSeen': paywallSeen,
        'restoreTapped': restoreTapped,
        'purchaseTapped': purchaseTapped,
      };

  factory BetaActivationLoopCounts.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const BetaActivationLoopCounts();
    int n(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return BetaActivationLoopCounts(
      appOpened: n('appOpened'),
      recordScreenSeen: n('recordScreenSeen'),
      firstMomentSaved: n('firstMomentSaved'),
      oneEntryReturnScreenSeen: n('oneEntryReturnScreenSeen'),
      secondMomentSaved: n('secondMomentSaved'),
      twoEntryRelatedSeen: n('twoEntryRelatedSeen'),
      twoEntryUnrelatedSeen: n('twoEntryUnrelatedSeen'),
      thirdMomentSaved: n('thirdMomentSaved'),
      confirmedRepeatSeen: n('confirmedRepeatSeen'),
      paywallSeen: n('paywallSeen'),
      restoreTapped: n('restoreTapped'),
      purchaseTapped: n('purchaseTapped'),
    );
  }

  String toSummaryText() {
    final buffer = StringBuffer('ArchiveMe beta activation loop\n');
    for (final entry in fieldLabels.entries) {
      buffer.writeln('${entry.value}: ${valueForField(entry.key)}');
    }
    return buffer.toString().trimRight();
  }
}
