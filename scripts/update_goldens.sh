#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/mobile"

echo "==> Running Golden Tests (Checking for failures)..."
flutter test test/release/ || true
echo ""
echo "🚨 ACTION REQUIRED: Open the 'failures/' directory and look at the images."
echo "Do the failures accurately reflect your recent UI changes? (y/n)"
read -p "> " confirm
if [ "$confirm" = "y" ]; then
  echo "==> Updating Goldens..."
  flutter test test/release/ --update-goldens
  echo "✅ Goldens updated."
else
  echo "❌ Update aborted. Please fix the UI code and run again."
  exit 1
fi
