#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
