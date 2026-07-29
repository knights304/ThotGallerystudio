#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found in PATH. Install Flutter, then run this script again." >&2
  exit 1
fi

if [[ ! -d android || ! -d ios ]]; then
  echo "Generating clean Android and iOS platform scaffolding..."
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  flutter create \
    --platforms=android,ios \
    --org com.thotgallery \
    --project-name thot_gallery_creator \
    "$TMP_DIR/scaffold"
  rm -rf android ios
  cp -a "$TMP_DIR/scaffold/android" .
  cp -a "$TMP_DIR/scaffold/ios" .
fi

flutter pub get
dart format lib test
flutter analyze
flutter test

echo
echo "Foundation checks passed."
echo "Connect the Tab S6 and run: flutter run -d <device-id>"
echo "Build APK: flutter build apk --debug"
