# Isolated pre-V1 Flutter source

This directory preserves source and tests removed from the commercial V1
dependency graph. It is not a Dart or Flutter package, has no `pubspec.yaml`,
is excluded from analysis and release CI, and must not be imported by
`apps/voicememory_mobile`.

Files are kept only as historical implementation evidence while the V1
reduction is reviewed. Restore a capability by designing it against the active
product contract, not by importing code from this directory into production.

Run `node scripts/archive-me-v1-release-architecture.mjs --check` to verify
that the shipping entry point cannot reach this workspace.
