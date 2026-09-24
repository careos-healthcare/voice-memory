import 'package:archiveme_mobile/core/services/activity_metadata_service.dart';
import 'package:flutter/material.dart';

/// Local picker used when activity detection has no label to offer.
abstract final class ActivityPickerSheet {
  static Future<ActivityMetadata?> show(BuildContext context) {
    return showModalBottomSheet<ActivityMetadata>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            key: const Key('activity_picker_sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final label in ActivityCatalog.labels)
                ListTile(
                  key: Key('activity_option_$label'),
                  title: Text(label),
                  onTap: () => Navigator.of(context).pop(
                    ActivityMetadata(
                      label: label,
                      source: ActivitySource.picked,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
