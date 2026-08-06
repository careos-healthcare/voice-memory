# archiveme_research

Non-shipping ArchiveMe lab surfaces quarantined from the V1 production router.

## Purpose

- Preserve capacity-loop, beta laboratory, legacy journal, pattern experiments, and developer verification screens
- Keep the production `voicememory_mobile` graph free of these imports
- Recoverable through Git; screens depend on `package:voicememory_mobile` for shared stores and features

## Usage

```bash
cd packages/archiveme_research
flutter test
```

Do **not** add `archiveme_research` to `voicememory_mobile` production dependencies.
