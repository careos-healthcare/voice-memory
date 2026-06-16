import '../loop_mode/loop_mode_model.dart';

/// Pressure-loop wedge selected during onboarding — analytics + ranking.
enum AudienceWedge {
  doingMoreToFeelEnough,
  feelingBehindWhenStop,
  guiltAroundRest,
  provingThroughWork,
  sayingYesNoCapacity,
  notSureYet,
  // Legacy persisted values — kept for storage compatibility.
  sayingYesCapacity,
  proveEnough,
  relationshipReplay,
  avoidingDirectConversations,
  repeatingHabit,
}

extension AudienceWedgeIds on AudienceWedge {
  static const onboardingChoices = [
    AudienceWedge.doingMoreToFeelEnough,
    AudienceWedge.feelingBehindWhenStop,
    AudienceWedge.guiltAroundRest,
    AudienceWedge.provingThroughWork,
    AudienceWedge.sayingYesNoCapacity,
    AudienceWedge.notSureYet,
  ];

  String get id => name;

  String get label {
    switch (this) {
      case AudienceWedge.doingMoreToFeelEnough:
        return 'Doing more to feel enough';
      case AudienceWedge.feelingBehindWhenStop:
        return 'Feeling behind when I stop';
      case AudienceWedge.guiltAroundRest:
        return 'Guilt around rest';
      case AudienceWedge.provingThroughWork:
        return 'Proving myself through work';
      case AudienceWedge.sayingYesNoCapacity:
      case AudienceWedge.sayingYesCapacity:
        return 'Saying yes with no capacity';
      case AudienceWedge.notSureYet:
        return 'Not sure yet';
      case AudienceWedge.proveEnough:
        return 'Trying to prove I am doing enough';
      case AudienceWedge.relationshipReplay:
        return 'Replaying relationship moments';
      case AudienceWedge.avoidingDirectConversations:
        return 'Avoiding direct conversations';
      case AudienceWedge.repeatingHabit:
        return 'Repeating the same habit';
    }
  }

  /// Loop activated from this wedge during onboarding.
  String get mappedLoopId {
    switch (this) {
      case AudienceWedge.sayingYesNoCapacity:
      case AudienceWedge.sayingYesCapacity:
        return LoopModeIds.capacityYes;
      case AudienceWedge.doingMoreToFeelEnough:
      case AudienceWedge.feelingBehindWhenStop:
      case AudienceWedge.guiltAroundRest:
      case AudienceWedge.provingThroughWork:
      case AudienceWedge.notSureYet:
      case AudienceWedge.proveEnough:
        return LoopModeIds.proveEnough;
      case AudienceWedge.relationshipReplay:
      case AudienceWedge.avoidingDirectConversations:
      case AudienceWedge.repeatingHabit:
        return LoopModeIds.notSure;
    }
  }

  bool get mapsToProveEnough => mappedLoopId == LoopModeIds.proveEnough;

  String get firstPrompt {
    switch (this) {
      case AudienceWedge.doingMoreToFeelEnough:
      case AudienceWedge.feelingBehindWhenStop:
      case AudienceWedge.guiltAroundRest:
      case AudienceWedge.provingThroughWork:
      case AudienceWedge.proveEnough:
        return 'When did you feel pressure to do more to feel okay?';
      case AudienceWedge.sayingYesNoCapacity:
      case AudienceWedge.sayingYesCapacity:
        return 'When did you say yes before checking whether you had room?';
      case AudienceWedge.relationshipReplay:
        return 'What interaction kept replaying in your head?';
      case AudienceWedge.avoidingDirectConversations:
        return 'What did you avoid saying directly?';
      case AudienceWedge.repeatingHabit:
        return 'What did you do again even though you noticed it?';
      case AudienceWedge.notSureYet:
        return 'When did you feel pressure to do more to feel okay?';
    }
  }

  List<String> get templateIds {
    switch (this) {
      case AudienceWedge.sayingYesNoCapacity:
      case AudienceWedge.sayingYesCapacity:
        return [
          'saying_yes_capacity',
          'disappoint_someone',
          'avoid_saying_no',
          'rest_but_more',
        ];
      case AudienceWedge.doingMoreToFeelEnough:
      case AudienceWedge.feelingBehindWhenStop:
      case AudienceWedge.guiltAroundRest:
      case AudienceWedge.provingThroughWork:
      case AudienceWedge.proveEnough:
      case AudienceWedge.notSureYet:
        return ['prove_enough', 'stay_in_control', 'achievement_feel_safe'];
      case AudienceWedge.relationshipReplay:
        return ['disappoint_someone', 'worry_returning'];
      case AudienceWedge.avoidingDirectConversations:
        return ['avoid_conversation', 'avoid_saying_no'];
      case AudienceWedge.repeatingHabit:
        return ['repeating_habit', 'saying_yes_capacity', 'avoid_conversation'];
    }
  }

  List<String> get supportKeywords {
    switch (this) {
      case AudienceWedge.sayingYesNoCapacity:
      case AudienceWedge.sayingYesCapacity:
        return [
          'yes',
          'agreed',
          'agree',
          'help',
          'capacity',
          'disappoint',
          'pressure',
        ];
      case AudienceWedge.doingMoreToFeelEnough:
      case AudienceWedge.feelingBehindWhenStop:
      case AudienceWedge.guiltAroundRest:
      case AudienceWedge.provingThroughWork:
      case AudienceWedge.proveEnough:
      case AudienceWedge.notSureYet:
        return [
          'prove',
          'enough',
          'behind',
          'achievement',
          'work',
          'pressure',
          'more',
          'rest',
          'guilty',
        ];
      case AudienceWedge.relationshipReplay:
        return [
          'replay',
          'interaction',
          'conversation',
          'disappoint',
          'said',
          'them',
          'they',
        ];
      case AudienceWedge.avoidingDirectConversations:
        return [
          'avoid',
          'say',
          'tell',
          'direct',
          'conversation',
          "didn't",
          'did not',
        ];
      case AudienceWedge.repeatingHabit:
        return ['again', 'repeat', 'habit', 'noticed', 'keep', 'same'];
    }
  }

  bool textSupports(String text) {
    if (this == AudienceWedge.notSureYet) return false;
    final lower = text.toLowerCase();
    return supportKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Maps legacy acquisition intent ids to wedges.
  static AudienceWedge? fromLegacyIntentId(String? id) {
    switch (id) {
      case 'workPressure':
        return AudienceWedge.sayingYesNoCapacity;
      case 'relationships':
        return AudienceWedge.relationshipReplay;
      case 'habitsRepeat':
        return AudienceWedge.repeatingHabit;
      case 'decisionsRepeat':
        return AudienceWedge.avoidingDirectConversations;
      case 'feelingStuck':
        return AudienceWedge.notSureYet;
      case 'notSureYet':
        return AudienceWedge.notSureYet;
      default:
        return null;
    }
  }
}
