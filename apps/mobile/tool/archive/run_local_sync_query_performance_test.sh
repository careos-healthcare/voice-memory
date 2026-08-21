#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mode="${1:-test}"
device="${DEVICE_ID:-}"

device_args=()
if [[ -n "$device" ]]; then
  device_args=(-d "$device")
fi

case "$mode" in
  test)
    # integration_test targets must run on a connected device or simulator.
    flutter test integration_test/local_sync_query_performance_test.dart "${device_args[@]}"
    ;;
  drive)
    flutter drive \
      --driver=integration_test/driver/local_sync_query_performance_driver.dart \
      --target=integration_test/local_sync_query_performance_test.dart \
      "${device_args[@]}"
    ;;
  update-budgets)
    UPDATE_PERF_BUDGETS=1 flutter test integration_test/local_sync_query_performance_test.dart "${device_args[@]}"
    ;;
  metrics-unit)
    flutter test test/integration/timeline_performance_metrics_test.dart
    ;;
  *)
    echo "Usage: $0 [test|drive|update-budgets|metrics-unit]" >&2
    echo "Set DEVICE_ID when no default device is available (e.g. iOS simulator id)." >&2
    exit 64
    ;;
esac
