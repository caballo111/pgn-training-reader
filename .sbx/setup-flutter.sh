#!/usr/bin/env bash
set -euo pipefail

# Run inside the sandbox. SDK files stay in the sandbox's home directory.
task_flutter_version=3.47.5
task_flutter_dir=/home/agent/flutter
if [[ ! -d "$task_flutter_dir/.git" ]]; then
  timeout 240 git clone --depth 1 --branch "$task_flutter_version" \
    https://github.com/flutter/flutter.git "$task_flutter_dir"
fi
test "$(git -C "$task_flutter_dir" describe --tags --exact-match)" = "$task_flutter_version"
timeout 600 "$task_flutter_dir/bin/flutter" config --no-analytics
timeout 600 "$task_flutter_dir/bin/flutter" precache --android
sudo ln -sf "$task_flutter_dir/bin/flutter" /usr/local/bin/flutter
sudo ln -sf "$task_flutter_dir/bin/dart" /usr/local/bin/dart
flutter --version
