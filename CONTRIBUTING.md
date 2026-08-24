# Contributing

Start with [`docs/ENGINEERING_CHARTER.md`](docs/ENGINEERING_CHARTER.md) and the Flutter app at [`apps/mobile`](apps/mobile). Privacy claims must match the code. Do not invent absolutes.

## Feature Budget Policy

There is no file named `feature_budget`. The budget is the V1 production allowlist and the gates that enforce it. Check these **before** adding a new top-level `apps/mobile/lib/features/` directory:

| File | What it constrains |
| --- | --- |
| [`apps/mobile/lib/core/config/v1_production_allowlist.dart`](apps/mobile/lib/core/config/v1_production_allowlist.dart) | Launch capabilities, startup phases, production router screens, blocked screens/packages |
| [`apps/mobile/lib/core/config/v1_launch_product_contract.dart`](apps/mobile/lib/core/config/v1_launch_product_contract.dart) | The nine customer-facing launch capabilities and banned claim patterns |
| [`apps/mobile/lib/core/config/v1_capability_registry.dart`](apps/mobile/lib/core/config/v1_capability_registry.dart) | Compile-time native capability allowlist (microphone, speech, caregiver flag, …) |
| [`apps/mobile/lib/core/config/v1_feature_flags.dart`](apps/mobile/lib/core/config/v1_feature_flags.dart) | `enableV1Only` master switch; non-core surfaces stay off while it is true |
| [`apps/mobile/docs/V1_PRODUCT_CONTRACT.md`](apps/mobile/docs/V1_PRODUCT_CONTRACT.md) | Human-readable launch contract |
| [`apps/mobile/docs/archive/2026-08/V1_PERMISSION_MATRIX.md`](apps/mobile/docs/archive/2026-08/V1_PERMISSION_MATRIX.md) | Native permission allowlist (kept with the archived V1 docs) |
| [`apps/mobile/tool/validate_v1_production_graph.sh`](apps/mobile/tool/validate_v1_production_graph.sh) | Production-graph validator (see also `apps/mobile/tool/gates.yaml`) |

Most entries under `apps/mobile/lib/features/` are symlinks into `apps/mobile/retired_sprawl/`. Real V1 directories are the exception. Reuse an existing feature, doc, or gate before adding a new top-level directory.

Enforced by `apps/mobile/test/v1_production_allowlist_test.dart` and the production-graph script above.
