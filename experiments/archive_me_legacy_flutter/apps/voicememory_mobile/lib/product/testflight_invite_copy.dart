import 'loop_acquisition_copy.dart';

/// Which TestFlight invite wedge to share with testers.
enum TestFlightInviteVariant { capacityYes, proveEnough, generic }

extension TestFlightInviteVariantIds on TestFlightInviteVariant {
  String get id {
    switch (this) {
      case TestFlightInviteVariant.capacityYes:
        return 'capacity_yes';
      case TestFlightInviteVariant.proveEnough:
        return 'prove_enough';
      case TestFlightInviteVariant.generic:
        return 'generic';
    }
  }

  LoopAcquisitionVariant get landing {
    switch (this) {
      case TestFlightInviteVariant.capacityYes:
        return LoopAcquisitionCopy.capacityYes;
      case TestFlightInviteVariant.proveEnough:
        return LoopAcquisitionCopy.proveEnough;
      case TestFlightInviteVariant.generic:
        return LoopAcquisitionCopy.generic;
    }
  }
}

/// SMS / WhatsApp, email / DM, and tester task scripts for TestFlight cohorts.
abstract class TestFlightInviteCopy {
  TestFlightInviteCopy._();

  static const String cohortRouteLabel =
      'Internal TestFlight route (in-app only — not a public link)';

  static String cohortRouteFor(TestFlightInviteVariant variant) {
    return variant.landing.cohortRoutePath ?? '/start/prove-enough';
  }

  static String shortText(TestFlightInviteVariant variant) {
    switch (variant) {
      case TestFlightInviteVariant.proveEnough:
        return '''
ArchiveMe TestFlight — proving-enough loop

I'm testing an app for ambitious people who keep doing more because stopping makes them feel behind.

${LoopAcquisitionCopy.proveEnough.headline}

Record one honest moment today, then one tomorrow, and see if the app catches the loop.

Route: ${cohortRouteFor(variant)} ($cohortRouteLabel)''';
      case TestFlightInviteVariant.capacityYes:
        return '''
ArchiveMe TestFlight — yes loop wedge

${LoopAcquisitionCopy.capacityYes.headline}

Save 3 yes moments where you felt pulled to agree, then review your yes loop.

Route: ${cohortRouteFor(variant)} ($cohortRouteLabel)''';
      case TestFlightInviteVariant.generic:
        return '''
ArchiveMe TestFlight

${LoopAcquisitionCopy.generic.headline}

${LoopAcquisitionCopy.generic.subheadline}

Route: ${cohortRouteFor(variant)} ($cohortRouteLabel)''';
    }
  }

  static String longText(TestFlightInviteVariant variant) {
    final landing = variant.landing;
    final bullets = landing.bullets.isEmpty
        ? ''
        : '\n\nWhat you will do:\n${landing.bullets.map((b) => '• $b').join('\n')}';

    return '''
Subject: ArchiveMe TestFlight — ${landing.headline}

Hi — you are invited to test ArchiveMe on TestFlight.

${landing.headline}

${landing.subheadline}$bullets

Tester task:
${testerTask(variant)}

$cohortRouteLabel: ${cohortRouteFor(variant)}

Reply with what felt clear and what felt confusing after two days.''';
  }

  static String testerTask(TestFlightInviteVariant variant) {
    switch (variant) {
      case TestFlightInviteVariant.capacityYes:
        return 'Use the app for two days. Record one moment where you said yes before checking capacity, then come back and record the next yes moment.';
      case TestFlightInviteVariant.proveEnough:
        return 'Record one moment where you kept doing more because stopping felt uncomfortable. Come back tomorrow and record the next proving moment.';
      case TestFlightInviteVariant.generic:
        return 'Save small moments when something stands out. Come back when another '
            'moment matters and note whether ArchiveMe helped you see what returned.';
    }
  }

  /// Full invite for clipboard — short + task + route helper.
  static String clipboardPack(TestFlightInviteVariant variant) {
    return '''
${shortText(variant)}

---

Tester task:
${testerTask(variant)}

${longText(variant)}''';
  }
}
