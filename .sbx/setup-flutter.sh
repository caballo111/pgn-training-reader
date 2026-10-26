#!/usr/bin/env bash
# Install Flutter and the Android platform tools into an EXISTING sbx sandbox.
# Prefer the v3 kit in .sbx/flutter-android when creating a new sandbox; install
# hooks do not run on sandboxes that already exist. Safe to rerun.
set -euo pipefail

flutter_version=3.47.5
flutter_dir=/home/agent/flutter
arch=$(uname -m)
sudo_cmd=()
if [ "$(id -u)" -ne 0 ]; then
  sudo_cmd=(sudo)
fi

"${sudo_cmd[@]}" apt-get update
"${sudo_cmd[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates curl git unzip xz-utils zip openjdk-21-jdk-headless libglu1-mesa adb

java_arch=$(dpkg --print-architecture)
"${sudo_cmd[@]}" ln -sfn "/usr/lib/jvm/java-21-openjdk-$java_arch" /opt/flutter-android-java
export JAVA_HOME=/opt/flutter-android-java

if [ ! -d "$flutter_dir/.git" ]; then
  timeout 900 git clone --depth 1 --branch "$flutter_version" \
    https://github.com/flutter/flutter.git "$flutter_dir"
fi
test "$(git -C "$flutter_dir" describe --tags --exact-match)" = "$flutter_version"

"$flutter_dir/bin/flutter" config --no-analytics --jdk-dir "$JAVA_HOME"
if [ "$arch" = x86_64 ]; then
  # In-sandbox APK builds additionally need the x86-64 Android SDK from the kit.
  "$flutter_dir/bin/flutter" precache --android
else
  # Linux arm64 can analyze and test, but Google's Android build tools are x86-64 only.
  "$flutter_dir/bin/flutter" precache --web
fi

"${sudo_cmd[@]}" ln -sf "$flutter_dir/bin/flutter" /usr/local/bin/flutter
"${sudo_cmd[@]}" ln -sf "$flutter_dir/bin/dart" /usr/local/bin/dart

if [ -f /etc/sandbox-persistent.sh ]; then
  grep -q '^export JAVA_HOME=' /etc/sandbox-persistent.sh || \
    printf 'export JAVA_HOME=%s\n' "$JAVA_HOME" | \
      "${sudo_cmd[@]}" tee -a /etc/sandbox-persistent.sh >/dev/null
  grep -q '^export ADB_SERVER_SOCKET=' /etc/sandbox-persistent.sh || \
    echo 'export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037' | \
      "${sudo_cmd[@]}" tee -a /etc/sandbox-persistent.sh >/dev/null
fi

flutter --version
adb version
if [ "$arch" != x86_64 ]; then
  echo "arm64: analyze/test are available; build APKs on the Mac or on an x86-64 sandbox."
fi
