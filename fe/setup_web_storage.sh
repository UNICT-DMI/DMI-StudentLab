#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/fe"
flutter clean
rm -rf .dart_tool build
flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter analyze
