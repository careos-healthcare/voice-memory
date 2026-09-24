/// Which step in the activation loop needs the most help.
enum ActivationLoopWeakestBucket {
  firstRecord,
  tomorrowCheck,
  returnDay,
  usefulResult,
  nextCheck,
  none,
}

extension ActivationLoopWeakestBucketIds on ActivationLoopWeakestBucket {
  String get id => name;
}

/// Six-step activation loop health derived from local event counts.
class ActivationLoopScore {
  const ActivationLoopScore({
    required this.savedFirstMoment,
    required this.choseTomorrowCheck,
    required this.returnedNextDay,
    required this.closedLoop,
    required this.ratedUsefulOrSortOf,
    required this.choseNextCheck,
    required this.completedFullLoop,
    required this.weakestBucket,
  });

  final bool savedFirstMoment;
  final bool choseTomorrowCheck;
  final bool returnedNextDay;
  final bool closedLoop;
  final bool ratedUsefulOrSortOf;
  final bool choseNextCheck;
  final bool completedFullLoop;
  final ActivationLoopWeakestBucket weakestBucket;

  Map<String, dynamic> toJson() => {
    'savedFirstMoment': savedFirstMoment,
    'choseTomorrowCheck': choseTomorrowCheck,
    'returnedNextDay': returnedNextDay,
    'closedLoop': closedLoop,
    'ratedUsefulOrSortOf': ratedUsefulOrSortOf,
    'choseNextCheck': choseNextCheck,
    'completedFullLoop': completedFullLoop,
    'weakestBucket': weakestBucket.id,
  };
}
