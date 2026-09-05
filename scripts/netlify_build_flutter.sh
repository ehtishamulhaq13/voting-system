#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.22.3}"

echo "Installing Flutter $FLUTTER_VERSION..."
curl -L "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o flutter.tar.xz
tar xf flutter.tar.xz
export PATH="$PWD/flutter/bin:$PATH"

flutter --version
flutter config --enable-web

flutter pub get

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:8000}"
echo "Building Flutter web with API_BASE_URL=$API_BASE_URL"

flutter build web --dart-define=API_BASE_URL=$API_BASE_URL
