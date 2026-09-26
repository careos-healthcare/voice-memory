import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_copy.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_schedule.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Settings toggles. Hidden while [V1CapabilityRegistry.gentleReminders] is off.
class GentleRemindersSettingsSection extends StatefulWidget {
  const GentleRemindersSettingsSection({
    super.key,
    this.settings = const GentleReminderSettings(),
    this.onChanged,
  });

  final GentleReminderSettings settings;
  final ValueChanged<GentleReminderSettings>? onChanged;

  @override
  State<GentleRemindersSettingsSection> createState() =>
      _GentleRemindersSettingsSectionState();
}

class _GentleRemindersSettingsSectionState
    extends State<GentleRemindersSettingsSection> {
  late GentleReminderSettings _settings = widget.settings;
  List<String> _scheduledIds = const [];

  @override
  void initState() {
    super.initState();
    if (V1CapabilityRegistry.gentleReminders) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.gentleReminders) {
      return const SizedBox.shrink();
    }
    final settings = _settings;
    return Column(
      children: [
        SwitchListTile(
          key: const Key('settings_gentle_daily'),
          contentPadding: EdgeInsets.zero,
          title: const Text(GentleRemindersCopy.settingsDaily),
          value: settings.dailyEnabled,
          onChanged: (value) => _update(settings.copyWith(dailyEnabled: value)),
        ),
        SwitchListTile(
          key: const Key('settings_gentle_on_this_day'),
          contentPadding: EdgeInsets.zero,
          title: const Text(GentleRemindersCopy.settingsOnThisDay),
          value: settings.onThisDayEnabled,
          onChanged: (value) =>
              _update(settings.copyWith(onThisDayEnabled: value)),
        ),
        SwitchListTile(
          key: const Key('settings_gentle_check_back'),
          contentPadding: EdgeInsets.zero,
          title: const Text(GentleRemindersCopy.settingsCheckBack),
          value: settings.checkBackEnabled,
          onChanged: (value) =>
              _update(settings.copyWith(checkBackEnabled: value)),
        ),
        SwitchListTile(
          key: const Key('settings_gentle_weekly_recap'),
          contentPadding: EdgeInsets.zero,
          title: const Text(GentleRemindersCopy.settingsWeeklyRecap),
          subtitle: Text(
            'Sunday ${_label(settings.weeklyHour * 60 + settings.weeklyMinute)}',
          ),
          value: settings.weeklyRecapEnabled,
          onChanged: (value) =>
              _update(settings.copyWith(weeklyRecapEnabled: value)),
        ),
        ListTile(
          key: const Key('settings_gentle_weekly_time'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Weekly recap time'),
          subtitle: Text(
            _label(settings.weeklyHour * 60 + settings.weeklyMinute),
          ),
          onTap: () => _pickWeeklyTime(context, settings),
        ),
        ListTile(
          key: const Key('settings_gentle_quiet_hours'),
          contentPadding: EdgeInsets.zero,
          title: const Text(GentleRemindersCopy.settingsQuietHours),
          subtitle: Text(
            settings.quietHours.isOff
                ? 'Off'
                : '${_label(settings.quietHours.startMinute)} – ${_label(settings.quietHours.endMinute)}',
          ),
          onTap: () => _pickQuietHours(context, settings),
        ),
      ],
    );
  }

  Future<void> _load() async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    final start = int.tryParse(
      await prefs.readString('gentle_quiet_start') ?? '',
    );
    final end = int.tryParse(await prefs.readString('gentle_quiet_end') ?? '');
    final ids = await prefs.readString('gentle_scheduled_ids');
    final daily = await prefs.readBool('gentle_daily') ?? false;
    final onThisDay = await prefs.readBool('gentle_on_this_day') ?? false;
    final checkBack = await prefs.readBool('gentle_check_back') ?? false;
    final weekly = await prefs.readBool('gentle_weekly') ?? true;
    final hour = int.tryParse(await prefs.readString('gentle_hour') ?? '') ?? 9;
    final minute =
        int.tryParse(await prefs.readString('gentle_minute') ?? '') ?? 0;
    final weeklyHour =
        int.tryParse(await prefs.readString('gentle_weekly_hour') ?? '') ??
        GentleReminderSchedule.weeklyRecapHour;
    final weeklyMinute =
        int.tryParse(await prefs.readString('gentle_weekly_minute') ?? '') ??
        0;
    if (!mounted) return;
    setState(() {
      _settings = GentleReminderSettings(
        dailyEnabled: daily,
        onThisDayEnabled: onThisDay,
        checkBackEnabled: checkBack,
        weeklyRecapEnabled: weekly,
        dailyHour: hour,
        dailyMinute: minute,
        weeklyHour: weeklyHour,
        weeklyMinute: weeklyMinute,
        quietHours: QuietHours(
          startMinute: start ?? 0,
          endMinute: end ?? 0,
        ),
      );
      _scheduledIds = (ids == null || ids.isEmpty) ? const [] : ids.split(',');
    });
  }

  Future<void> _update(GentleReminderSettings next) async {
    setState(() => _settings = next);
    widget.onChanged?.call(next);
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    await prefs.writeBool('gentle_daily', next.dailyEnabled);
    await prefs.writeBool('gentle_on_this_day', next.onThisDayEnabled);
    await prefs.writeBool('gentle_check_back', next.checkBackEnabled);
    await prefs.writeBool('gentle_weekly', next.weeklyRecapEnabled);
    await prefs.writeString('gentle_hour', '${next.dailyHour}');
    await prefs.writeString('gentle_minute', '${next.dailyMinute}');
    await prefs.writeString('gentle_weekly_hour', '${next.weeklyHour}');
    await prefs.writeString('gentle_weekly_minute', '${next.weeklyMinute}');
    await prefs.writeString(
      'gentle_quiet_start',
      '${next.quietHours.startMinute}',
    );
    await prefs.writeString('gentle_quiet_end', '${next.quietHours.endMinute}');
    final ids = await GentleRemindersService().sync(
      settings: next,
      previouslyScheduledIds: _scheduledIds,
      now: DateTime.now(),
    );
    _scheduledIds = ids;
    await prefs.writeString('gentle_scheduled_ids', ids.join(','));
  }

  Future<void> _pickQuietHours(
    BuildContext context,
    GentleReminderSettings settings,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.quietHours.startMinute ~/ 60,
        minute: settings.quietHours.startMinute % 60,
      ),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.quietHours.endMinute ~/ 60,
        minute: settings.quietHours.endMinute % 60,
      ),
    );
    if (end == null) return;
    await _update(
      settings.copyWith(
        quietHours: QuietHours(
          startMinute: start.hour * 60 + start.minute,
          endMinute: end.hour * 60 + end.minute,
        ),
      ),
    );
  }

  Future<void> _pickWeeklyTime(
    BuildContext context,
    GentleReminderSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.weeklyHour,
        minute: settings.weeklyMinute,
      ),
    );
    if (picked == null) return;
    await _update(
      settings.copyWith(weeklyHour: picked.hour, weeklyMinute: picked.minute),
    );
  }

  static String _label(int minute) {
    final hour = (minute ~/ 60).toString().padLeft(2, '0');
    final min = (minute % 60).toString().padLeft(2, '0');
    return '$hour:$min';
  }
}

/// Shown only after the third entry, and only when the flag is on.
class GentleReminderOptIn extends StatefulWidget {
  const GentleReminderOptIn({
    required this.entryCount,
    this.alreadyAnswered = false,
    super.key,
    this.onTurnOn,
    this.onNotNow,
  });

  final int entryCount;
  final bool alreadyAnswered;
  final VoidCallback? onTurnOn;
  final VoidCallback? onNotNow;

  @override
  State<GentleReminderOptIn> createState() => _GentleReminderOptInState();
}

class _GentleReminderOptInState extends State<GentleReminderOptIn> {
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _answered = widget.alreadyAnswered;
    if (V1CapabilityRegistry.gentleReminders && !_answered) {
      unawaited(_load());
    }
    if (V1CapabilityRegistry.notifications && widget.entryCount >= 3) {
      unawaited(_requestNotificationPermission());
    }
  }

  Future<void> _requestNotificationPermission() async {
    await CheckInReminderService.ensureInitialized();
    await CheckInReminderService.backend.requestPermission();
  }

  Future<void> _load() async {
    if (!AppServices.isInitialized) return;
    final answered =
        await AppServices.instance.prefs.readBool('gentle_opt_in_answered') ??
        false;
    if (mounted) setState(() => _answered = answered);
  }

  Future<void> _answer(VoidCallback? callback) async {
    setState(() => _answered = true);
    if (AppServices.isInitialized) {
      await AppServices.instance.prefs.writeBool(
        'gentle_opt_in_answered',
        true,
      );
    }
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.gentleReminders ||
        !GentleReminderSchedule.offerAfterThirdEntry(
          entryCount: widget.entryCount,
          alreadyAnswered: _answered,
        )) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const Key('gentle_reminder_opt_in'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(GentleRemindersCopy.optInTitle),
        const Text(GentleRemindersCopy.optInBody),
        TextButton(
          key: const Key('gentle_reminder_opt_in_turn_on'),
          onPressed: () => _answer(widget.onTurnOn),
          child: const Text(GentleRemindersCopy.turnOn),
        ),
        TextButton(
          key: const Key('gentle_reminder_opt_in_not_now'),
          onPressed: () => _answer(widget.onNotNow),
          child: const Text(GentleRemindersCopy.notNow),
        ),
      ],
    );
  }
}
