import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/domain/weekly_topic_synthesis.dart';
/// Persists weekly synthesis nodes in the reflection graph tables + FTS5 index.
final class WeeklySynthesisRepository {
  WeeklySynthesisRepository(AppDatabase db) : _dao = db.reflectionGraphDao;

  final ReflectionGraphDao _dao;

  Future<bool> hasSynthesisForWeek(String weekKey) =>
      _dao.hasWeeklySynthesisForWeek(weekKey);

  Future<void> saveSynthesis(WeeklyTopicSynthesis synthesis) =>
      _dao.saveWeeklySynthesis(synthesis);
}
