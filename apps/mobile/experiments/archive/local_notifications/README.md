# Archived local notification implementations

These files require `flutter_local_notifications` and `timezone` — **not** linked in the focused V1 beta (`V1CapabilityRegistry.notifications = false`).

Production uses stub backends in:

- `lib/features/tomorrow_return/local_check_in_reminder_backend.dart`
- `lib/features/curiosity_loop/services/curiosity_notification_scheduler.dart`

## Re-enable checklist

1. Set `V1CapabilityRegistry.notifications = true` and update docs/audit.
2. Add to `pubspec.yaml`: `flutter_local_notifications`, `timezone`.
3. Replace stubs with conditional exports pointing at the archived `*_impl.dart` files (or move impl back into `lib/`).
4. Restore Android `ScheduledNotificationBootReceiver` in the manifest if required by the plugin version.
5. Run `flutter pub get` and verify `GeneratedPluginRegistrant` registers the plugin.
