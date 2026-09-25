import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_schedule.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';

class GentleReminderSettings {
  const GentleReminderSettings({
    this.dailyEnabled = false,
    this.onThisDayEnabled = false,
    this.checkBackEnabled = false,
    this.dailyHour = 9,
    this.dailyMinute = 0,
    this.quietHours = QuietHours.off,
  });

  final bool dailyEnabled;
  final bool onThisDayEnabled;
  final bool checkBackEnabled;
  final int dailyHour;
  final int dailyMinute;
  final QuietHours quietHours;
}

/// Schedules and cancels local reminders. Does nothing while the flag is off,
/// except cancelling ids the caller still has from an earlier session.
class GentleRemindersService {
  GentleRemindersService({CheckInReminderBackend? backend})
    : backend = backend ?? CheckInReminderService.backend;

  final CheckInReminderBackend backend;

  Future<List<String>> sync({
    required GentleReminderSettings settings,
    required List<String> previouslyScheduledIds,
    required DateTime now,
    List<OnThisDayCandidate> entries = const [],
  }) async {
    if (!V1CapabilityRegistry.gentleReminders) {
      await cancel(previouslyScheduledIds);
      return const [];
    }
    final notices = <GentleReminderNotice>[
      ...GentleReminderSchedule.dailySlots(
        enabled: settings.dailyEnabled,
        now: now,
        hour: settings.dailyHour,
        minute: settings.dailyMinute,
        quietHours: settings.quietHours,
      ),
      ...GentleReminderSchedule.onThisDay(
        enabled: settings.onThisDayEnabled,
        now: now,
        entries: entries,
        quietHours: settings.quietHours,
      ),
    ];
    return _replace(
      previouslyScheduledIds: previouslyScheduledIds,
      notices: notices,
      keepCheckBack: settings.checkBackEnabled,
    );
  }

  Future<List<String>> scheduleCheckBack({
    required String entryId,
    required String verbatimQuote,
    required DateTime now,
    required List<String> previouslyScheduledIds,
    QuietHours quietHours = QuietHours.off,
    bool enabled = true,
  }) async {
    if (!V1CapabilityRegistry.gentleReminders || !enabled) {
      await cancel([GentleReminderSchedule.checkBackId(entryId)]);
      return previouslyScheduledIds
          .where((id) => id != GentleReminderSchedule.checkBackId(entryId))
          .toList();
    }
    final notice = GentleReminderSchedule.checkBack(
      entryId: entryId,
      verbatimQuote: verbatimQuote,
      now: now,
      quietHours: quietHours,
    );
    await backend.schedule(
      checkInId: notice.id,
      title: notice.title,
      body: notice.body,
      when: notice.when,
      payload: notice.id,
    );
    return {...previouslyScheduledIds, notice.id}.toList();
  }

  /// Reloads saved reminder settings and refreshes the next 14 daily slots.
  Future<void> rescheduleReminders({DateTime? now}) async {
    if (!V1CapabilityRegistry.gentleReminders || !AppServices.isInitialized) {
      return;
    }
    await CheckInReminderService.ensureInitialized();
    final prefs = AppServices.instance.prefs;
    final start = int.tryParse(
      await prefs.readString('gentle_quiet_start') ?? '',
    );
    final end = int.tryParse(await prefs.readString('gentle_quiet_end') ?? '');
    final stored = await prefs.readString('gentle_scheduled_ids');
    final previous = (stored == null || stored.isEmpty)
        ? const <String>[]
        : stored.split(',');
    final settings = GentleReminderSettings(
      dailyEnabled: await prefs.readBool('gentle_daily') ?? false,
      onThisDayEnabled: await prefs.readBool('gentle_on_this_day') ?? false,
      checkBackEnabled: await prefs.readBool('gentle_check_back') ?? false,
      dailyHour: int.tryParse(await prefs.readString('gentle_hour') ?? '') ?? 9,
      dailyMinute:
          int.tryParse(await prefs.readString('gentle_minute') ?? '') ?? 0,
      quietHours: QuietHours(
        startMinute: start ?? 0,
        endMinute: end ?? 0,
      ),
    );
    final ids = await sync(
      settings: settings,
      previouslyScheduledIds: previous,
      now: now ?? DateTime.now(),
    );
    await prefs.writeString('gentle_scheduled_ids', ids.join(','));
  }

  Future<void> cancel(List<String> ids) async {
    for (final id in ids) {
      await backend.cancel(id);
    }
  }

  Future<List<String>> _replace({
    required List<String> previouslyScheduledIds,
    required List<GentleReminderNotice> notices,
    required bool keepCheckBack,
  }) async {
    final nextIds = notices.map((notice) => notice.id).toSet();
    for (final id in previouslyScheduledIds) {
      final keep = id.startsWith('gentle.check_back.') && keepCheckBack;
      if (!nextIds.contains(id) && !keep) {
        await backend.cancel(id);
      }
    }
    for (final notice in notices) {
      await backend.schedule(
        checkInId: notice.id,
        title: notice.title,
        body: notice.body,
        when: notice.when,
        payload: notice.id,
      );
    }
    final keptCheckBack = keepCheckBack
        ? previouslyScheduledIds.where(
            (id) => id.startsWith('gentle.check_back.'),
          )
        : const <String>[];
    return {...nextIds, ...keptCheckBack}.toList();
  }
}
