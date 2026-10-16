#!/usr/bin/env bash
# Builds Voxlab and installs it on the booted iOS simulator.
#
#   scripts/ios_sim.sh          demo: no login, server content, starts on the map
#   scripts/ios_sim.sh prod     real app: login with your account
#   scripts/ios_sim.sh offline  demo with the offline fixture content
#
# Content changes on the server do not need a rebuild: reopen the app or
# pull down on the map to refresh.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$PATH"

case "${1:-demo}" in
  demo)    args=(-t lib/main_demo.dart --dart-define=DEMO_SIGNED_IN=true) ;;
  offline) args=(-t lib/main_demo.dart --dart-define=DEMO_SIGNED_IN=true --dart-define=DEMO_FIXTURES=true) ;;
  prod)    args=(-t lib/main.dart) ;;
  *) echo "Uso: $0 [demo|prod|offline]" >&2; exit 2 ;;
esac

if ! xcrun simctl list devices booted | grep -q Booted; then
  echo "Abriendo el simulador..."
  open -a Simulator
  xcrun simctl boot "iPhone 16" 2>/dev/null || true
  xcrun simctl bootstatus "iPhone 16" -b >/dev/null
fi

flutter build ios --simulator --debug "${args[@]}"
APP=build/ios/iphonesimulator/Runner.app
xcrun simctl install booted "$APP"
xcrun simctl launch --terminate-running-process booted \
  "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
echo "Listo: Voxlab (${1:-demo}) corriendo en el simulador."
