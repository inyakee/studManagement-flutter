#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter config --enable-web --no-analytics
flutter pub get
if [ ! -f config/app.json ]; then
    cp config/app.example.json config/app.json
fi
bash scripts/start.sh
