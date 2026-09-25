import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Locale-aware dates. Uses the app locale, then the device locale.
abstract class LocaleDateFormat {
  LocaleDateFormat._();

  static String date(BuildContext context, DateTime value) =>
      DateFormat.yMMMd(_locale(context)).format(value.toLocal());

  static String time(BuildContext context, DateTime value) =>
      DateFormat.jm(_locale(context)).format(value.toLocal());

  static String dateTime(BuildContext context, DateTime value) =>
      DateFormat.yMMMd(_locale(context)).add_jm().format(value.toLocal());

  static String month(BuildContext context, DateTime value) =>
      DateFormat.MMMM(_locale(context)).format(value.toLocal());

  static String weekdayInitial(BuildContext context, DateTime value) =>
      DateFormat('EEEEE', _locale(context)).format(value.toLocal());

  static String _locale(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    if (locale != null) return locale.toString();
    final system = Intl.systemLocale;
    return system.isEmpty ? 'en' : system;
  }
}
