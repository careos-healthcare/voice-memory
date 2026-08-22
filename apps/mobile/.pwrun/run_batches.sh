#!/bin/bash
# Batched paywall test runner. Usage: run_batches.sh <outdir>
OUT="$1"
mkdir -p "$OUT"
FILES=(
test/annual_first_paywall_test.dart
test/archive_intelligence_pro_paywall_test.dart
test/archive_paywall_copy_test.dart
test/archive_paywall_stats_test.dart
test/delayed_paywall_proof_test.dart
test/features/monetization/revenuecat_paywall_presenter_test.dart
test/paywall_accessibility_test.dart
test/paywall_alignment_test.dart
test/paywall_archive_branding_test.dart
test/paywall_conversion_clarity_test.dart
test/paywall_conversion_copy_test.dart
test/paywall_copy_alignment_test.dart
test/paywall_cta_lift_test.dart
test/paywall_launch_copy_test.dart
test/paywall_objection_follow_up_test.dart
test/paywall_objection_handling_test.dart
test/paywall_purchase_confidence_test.dart
test/paywall_rejection_capture_test.dart
test/paywall_restore_test.dart
test/paywall_source_attribution_test.dart
test/paywall_subscription_details_test.dart
test/paywall_timing_gates_test.dart
test/paywall_timing_test.dart
test/paywall_trigger_engine_test.dart
test/paywall_unavailable_buttons_test.dart
test/paywall_value_repair_test.dart
test/paywall_value_sharpening_test.dart
test/pro_preview_before_paywall_test.dart
test/v1_paywall_controller_test.dart
test/v1_paywall_wiring_test.dart
test/value_moment_paywall_test.dart
)
i=0
batch=0
while [ $i -lt ${#FILES[@]} ]; do
  chunk=("${FILES[@]:$i:4}")
  batch=$((batch+1))
  echo "### BATCH $batch: ${chunk[*]}"
  avail=$(df -m /Users/chiragpatel | awk 'NR==2{print $4}')
  echo "### free_mb=$avail"
  if [ "$avail" -lt 1500 ]; then echo "### ABORT: below 1.5GB"; exit 9; fi
  flutter test --no-pub --reporter json "${chunk[@]}" > "$OUT/batch$batch.json" 2>"$OUT/batch$batch.err"
  echo "### batch $batch exit=$?"
  i=$((i+4))
done
echo "### ALL DONE"
df -m /Users/chiragpatel | awk 'NR==2{print "### final_free_mb="$4}'
