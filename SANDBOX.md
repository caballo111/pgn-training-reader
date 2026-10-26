# Local SBX sandbox

Tooling is provisioned three ways:

- `sbxenv.yaml` — schema version 1 workflow used by the original Codex sandbox.
  Its `postCreate` hook runs `.sbx/setup-flutter.sh` on the host via `sbx exec`.
- `.sbx/flutter-android` — a v3 kit (mixin) for `sbx run --kit`, which installs
  Flutter, JDK 21 and ADB while the sandbox is created.
- `.sbx/setup-flutter.sh` — installs the same tools into an existing sandbox and
  is safe to rerun.

Flutter is pinned to 3.47.5 to match `.fvmrc`. On this Apple Silicon host the
sandbox is Linux **arm64**: `flutter pub get`, `flutter analyze` and
`flutter test` work inside it. Android APK builds do not, because Google's Linux
Android build tools are x86-64 only. Run `flutter build apk` and `flutter run` on
the Mac, or use an x86-64 sbx (with sbx 0.46+, `--platform` is cloud-only). Install
hooks only run at creation; reattaching does not apply kit changes.

From this project directory (replace the name with the output of `sbx ls`):

```sh
# Existing sandbox
sbx exec pgn-training-reader bash .sbx/setup-flutter.sh

# New sandbox with the v3 kit, on the OpenCode or Codex workload image
sbx run docker/sbx-kit-opencode:latest \
  --name pgn-training-reader --kit ./.sbx/flutter-android \
  --cpus 4 --memory 6g
sbx run docker/sbx-kit-codex:latest \
  --name pgn-training-reader --kit ./.sbx/flutter-android \
  --cpus 4 --memory 6g
```

The legacy schema version 1 flow from `sbxenv.yaml` is still available:

```sh
sbx env create --auto-approve .
sbx env run .
sbx env exec . -- flutter --version
sbx env exec . -- flutter test
```

The project directory is shared with the host; edits are visible in both places.
SBX mounts the environment file read-only inside the sandbox.

Use `flutter` and `dart` directly inside the environment; the SDK is installed at
`/home/agent/flutter`, so FVM is not required there. When changing the Flutter
version, update both `.fvmrc` and the provisioning files and recreate the sandbox.

On the host, `.fvmrc` is only a version pin: any Flutter 3.47.5 SDK on `PATH` can
run the commands below. FVM is optional and is not required to build or publish.

To stop or remove this project's sandbox:

```sh
sbx stop pgn-training-reader   # v3
sbx env rm --force .           # v1
```

Removal retains project files and the global OAuth credential.

## Android devices and ADB

The phone and its PGN files stay outside the sandbox. Do not mount or copy the
host's Flutter, JDK or Android SDK: those are macOS binaries and cannot execute in
the Linux VM. Mounting host toolchains would also tie the sandbox to host state
and defeat the point of the sandbox. Only the ADB control channel crosses the
boundary:

```sh
# On the Mac: start the server and allow the socket through sbx policy
adb start-server
sbx policy allow network --sandbox pgn-training-reader localhost:5037
```

Inside the sandbox, `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037` connects the
native arm64 ADB client to the Mac's ADB server (the setup script sets this
persistently). Verify with `adb devices -l` and `flutter devices`. Installing an
emulator or copying PGN files into the sandbox is out of scope. The Android SDK
needed for in-sandbox builds is only installed on x86-64 kit sandboxes; ARM64
sandboxes get ADB and JDK only.

## Switching between host and sandbox builds

Flutter generates `.dart_tool/package_config.json`, plugin metadata and native
asset/build caches with absolute SDK/cache paths. The shared workspace exposes
these files to both machines, but the Mac host and Linux sandbox have different
paths and native binaries. Regenerate these files when switching environments;
package configuration from `/home/agent` cannot be used for a Mac build.

On the host, use the pinned SDK directly (no FVM needed):

```sh
flutter clean
flutter pub get
flutter build apk --debug
flutter build appbundle --release
```

Use equivalent `fvm flutter` commands only if you already use FVM. Avoid
`--no-pub` immediately after switching environments: a sandbox-side `pub get`
rewrites `.dart_tool` and `.flutter-plugins-dependencies` with `/home/agent`
paths, and the Mac must regenerate them with its own `flutter pub get` before the
next host build. Sandbox validation should move its generated caches aside before
handing the shared workspace back to the host, or run in a copy as described
below. This affects generated build data, not source files.

### Keeping host caches Mac-only

If the sandbox only needs `analyze`/`test`, work from a copy instead of the shared
tree. The current sandbox uses `/home/agent/work`; refresh it before running
checks:

```sh
rsync -a --delete --exclude .git --exclude build --exclude .dart_tool \
  --exclude .idea --exclude .DS_Store "$PWD/" /home/agent/work/
cd /home/agent/work && flutter pub get && flutter analyze && flutter test
```

Because `.dart_tool` is excluded from the sync, the copy keeps its Linux package
configuration and the shared tree keeps the Mac one. The host then needs
`flutter pub get` only when `pubspec.yaml`/lock dependencies actually change, not
after every sandbox test run.

## Codex authentication

ChatGPT authentication is handled by SBX on the host using the global OpenAI
OAuth credential in the OS keychain. Do not run `codex login` inside the sandbox.
The proxy can make `codex login status` report API-key authentication even when
the host uses OAuth. The credential is not stored in the project.

## Codex MCP compatibility

SBX 0.45.1 generated unsupported `type` and `headers` fields for its MCP
gateway. These were corrected for Codex 0.159.1 by removing `type` and renaming
the `headers` table to `http_headers`, preserving the authorization value.
The original config is backed up inside the sandbox as
`/home/agent/.codex/config.toml.before-mcp-fix`.

If SBX regenerates the old fields after recreation or a restart, rerun the
idempotent repair script:

```sh
sbx exec pgn-training-reader python3 .sbx/fix-codex-mcp.py
```
