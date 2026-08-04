/// Markdown import hooks for Archive Packs — parser only, no UI yet.
abstract class ArchivePackMarkdownImport {
  ArchivePackMarkdownImport._();

  static ArchivePackMarkdownDocument? parse(String markdown) {
    final lines = markdown.split('\n');
    String? packName;
    final instructions = StringBuffer();
    final entries = <String>[];
    var section = '';

    for (final line in lines) {
      if (line.startsWith('# Pack')) {
        packName = line.replaceFirst('# Pack', '').trim();
        section = 'pack';
        continue;
      }
      if (line.startsWith('## Instructions')) {
        section = 'instructions';
        continue;
      }
      if (line.startsWith('## Entries')) {
        section = 'entries';
        continue;
      }
      switch (section) {
        case 'instructions':
          if (line.trim().isNotEmpty) {
            instructions.writeln(line);
          }
        case 'entries':
          if (line.trim().isNotEmpty) {
            entries.add(line.trim());
          }
        default:
          break;
      }
    }

    if (packName == null || packName.isEmpty) return null;
    return ArchivePackMarkdownDocument(
      packName: packName,
      instructions: instructions.toString().trim(),
      entryTexts: entries,
    );
  }
}

class ArchivePackMarkdownDocument {
  const ArchivePackMarkdownDocument({
    required this.packName,
    required this.instructions,
    required this.entryTexts,
  });

  final String packName;
  final String instructions;
  final List<String> entryTexts;
}
