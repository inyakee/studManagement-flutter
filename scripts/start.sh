#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .logs
if [ ! -f config/app.json ]; then cp config/app.example.json config/app.json; fi
if python3 -c 'import socket; s=socket.socket(); exit(s.connect_ex(("127.0.0.1",8080)))'; then
    echo 'Student Pocket is already running on port 8080.'
    exit 0
fi
flutter build web --dart-define-from-file=config/app.json
setsid -f python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web >.logs/server.log 2>&1 </dev/null
for attempt in {1..30}; do
    if curl --silent --fail http://127.0.0.1:8080/ >/dev/null; then
        echo 'Student Pocket is ready. Open forwarded port 8080.'
        exit 0
    fi
    sleep 1
done
tail -20 .logs/server.log
exit 1
