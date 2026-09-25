import 'package:file_picker/file_picker.dart';

/// Opens the system image picker and returns local file paths.
Future<List<String>> pickEntryImages() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: true,
  );
  if (result == null) return const [];
  return [
    for (final file in result.files)
      if ((file.path ?? '').trim().isNotEmpty) file.path!.trim(),
  ];
}
