#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter analyze
flutter test
flutter build web --dart-define-from-file=config/app.json
echo 'Build complete. Refresh the browser. If port 8080 is stopped, run bash scripts/start.sh.'
