import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/core_access.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core loop features are free', () {
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.recordMoment), isTrue);
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.firstPattern), isTrue);
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.tomorrowCheck), isTrue);
    expect(
      ArchiveProFeatureMap.isFree(ArchiveFeature.returnComparison),
      isTrue,
    );
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.usefulTakeaway), isTrue);
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.routineAnchor), isTrue);
    expect(
      ArchiveProFeatureMap.isFree(ArchiveFeature.lastSevenKeyMoments),
      isTrue,
    );
  });

  test('featureLabel and featureBenefit aliases work', () {
    expect(
      ArchiveProFeatureMap.featureLabel(ArchiveFeature.patternMap),
      ArchiveProFeatureMap.proFeatureLabel(ArchiveFeature.patternMap),
    );
    expect(
      ArchiveProFeatureMap.featureBenefit(ArchiveFeature.patternMap),
      ArchiveProFeatureMap.proFeatureBenefit(ArchiveFeature.patternMap),
    );
  });

  test('long-term archive memory features are Pro', () {
    for (final feature in ArchiveProFeatureMap.proFeatures) {
      expect(ArchiveProFeatureMap.isPro(feature), isTrue);
      expect(ArchiveProFeatureMap.proFeatureLabel(feature), isNotEmpty);
      expect(ArchiveProFeatureMap.proFeatureBenefit(feature), isNotEmpty);
    }
  });

  test('saved moments are not capped by a usage count', () {
    expect(CoreAccess.canRecord, isTrue);
    expect(CoreAccess.canTranscribeLocally, isTrue);
    expect(CoreAccess.canPlayBack, isTrue);
    expect(CoreAccess.canSaveText, isTrue);
    expect(CoreAccess.statement, ConsumerUiCopy.coreIsFreeForever);
  });
}