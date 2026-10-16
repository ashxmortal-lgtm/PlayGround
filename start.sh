#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p pwd
PROJECT_ROOT="$(pwd)"
/usr/bin/time -p test -f dist/index.html
PORT="${PORT:-3000}"
/usr/bin/time -p echo "PORT=$PORT PROJECT_ROOT=$PROJECT_ROOT"
/usr/bin/time -p bash -c 'if [ -f package.json ]; then echo "package.json found"; else echo "no package.json, static mode"; fi'
/usr/bin/time -p bash -c 'if [ -f package.json ]; then if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi; fi'
/usr/bin/time -p bash -c 'if [ -f package.json ] && node -e "const p=require(\"./package.json\"); process.exit(p.scripts&&p.scripts.build?0:1)"; then npm run build; else echo "no build step"; fi'
/usr/bin/time -p test -f dist/index.html
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
/usr/bin/time -p mkdir -p "$WEB_DIR"
/usr/bin/time -p bash -c 'PROJECT_ROOT="$(pwd)"; WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"; printf "%s" "{\"project\":\"$PROJECT_ROOT\",\"directory\":\"$PROJECT_ROOT/dist\"}" > "$WEB_DIR/deployment-output.json"; cat "$WEB_DIR/deployment-output.json"; echo'
PROJECT_ROOT="$(pwd)"
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
printf '%s' "{\"project\":\"$PROJECT_ROOT\",\"directory\":\"$PROJECT_ROOT/dist\"}" > "$WEB_DIR/deployment-output.json"
/usr/bin/time -p cat "$WEB_DIR/deployment-output.json"
/usr/bin/time -p echo "serving $PROJECT_ROOT/dist on 0.0.0.0:$PORT"
/usr/bin/time -p python3 --version
/usr/bin/time -p python3 -m http.server "$PORT" --directory dist --bind 0.0.0.0
