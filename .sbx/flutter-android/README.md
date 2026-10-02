# Flutter tools for the Codex sandbox

This v3 mixin extends `docker/sbx-kit-codex:latest`. It preserves the published
Codex workload's configuration and installs tools during sandbox creation.

| Sandbox architecture | Installed tools | Workflow |
| --- | --- | --- |
| ARM64 (local Apple Silicon) | Flutter 3.47.5, web artifacts, JDK 21, Debian's native ADB | Run Flutter analysis and tests in the sandbox; run Android builds and `flutter run` on the Mac |
| x86-64 | Flutter 3.47.5, JDK 21, Android SDK 36, build tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1, ADB | Build Android apps in the sandbox |

Google's Linux Android build tools require x86-64. ARM64 setup deliberately skips
the Android SDK and reports this limitation; `flutter doctor` will report the
missing Android toolchain there. Device access through ADB does not enable
Android compilation on ARM64. Mac SDK binaries cannot run inside Linux.
In sbx v0.46.0, `--platform` is cloud-only, so the local command below cannot
select x86-64 on Apple Silicon.

## Create and run

Start the Mac's ADB server if you want access to attached Android devices, then
run from the repository root:

```sh
adb start-server
sbx run docker/sbx-kit-codex:latest \
  --name pgn-training-reader --kit ./.sbx/flutter-android \
  --cpus 4 --memory 6g
```

Install hooks run during creation. Reattaching to an existing sandbox does not
apply kit changes. If an earlier failed attempt left a sandbox with this name,
inspect `sbx ls` before retrying. To replace that sandbox, first preserve any
files stored only inside it, then run `sbx rm pgn-training-reader` and the creation
command above. Removing it discards its installed tools and internal files.

After successful creation, reattach with:

```sh
sbx run --name pgn-training-reader
```

The root `sbxenv.yaml` uses the older built-in `codex` workflow and its separate
Flutter script. It does not apply this v3 mixin; use the commands in this README.
`latest` follows the publisher's updates for newly created sandboxes.

## Build requirements

With sbx v0.46.0, `sbx kit validate ./.sbx/flutter-android` fails with
"no kit builder configured" because that command cannot build v3 sources.
`sbx run` builds and loads the local source instead. In the tested local setup,
this build requires the Docker engine selected by your Docker context to be
running, even though running `sbx` itself does not require host Docker.

You can check descriptor compilation without creating a sandbox or installing
SDKs:

```sh
docker buildx build -f .sbx/flutter-android/flutter-android.yaml \
  .sbx/flutter-android --output type=oci,dest=/tmp/flutter-android-kit.tar
```

This checks the kit image; it does not execute installation hooks.
There is no `sbx kit build` command.

The current Codex image uses Debian Trixie and a DHI package repository. The kit
allows `deb.debian.org`, `security.debian.org`, and `dhi.io` on ports 80 and 443
for package installation, plus Ubuntu mirrors for compatibility with older
images. A proxy `403 Forbidden` during `apt-get update` indicates blocked network
access; the subsequent "repository is not signed" message is a consequence of
that failed download. Keep APT signature verification enabled.

## Versions and installation

Installation downloads several GB and runs once per new sandbox. Flutter and
the main Android package versions are pinned. Distribution packages and Google's
`platform-tools` resolve at installation time. Override versions with
`--kit-arg flutterVersion=...`, `--kit-arg androidApi=...`,
`--kit-arg buildToolsVersion=...`, `--kit-arg ndkVersion=...`, or
`--kit-arg commandLineToolsVersion=...`. Android package arguments only affect
x86-64 installation. On x86-64, the hook accepts Android SDK licenses during
installation; review those licenses before creating the sandbox.

## Verify and access devices

Inside the sandbox:

```sh
uname -m
flutter --version
java -version
flutter doctor -v
adb devices -l
flutter pub get
flutter analyze
flutter test
```

On x86-64, you can also run `flutter build apk` and `flutter devices`.
On ARM64, run `flutter build apk`, `flutter devices`, and `flutter run` on the Mac
using its Flutter and Android SDK installations.

`ADB_SERVER_SOCKET=tcp:host.docker.internal:5037` connects the native sandbox ADB
client to the host's ADB server. Keep the host server listening on localhost.
The kit requests network access to `localhost:5037`; if your policy requires an
explicit grant:

```sh
sbx policy allow network --sandbox pgn-training-reader localhost:5037
```

Device discovery does not verify hot reload. Dart VM service ports may need
additional forwarding and policy rules. This kit does not launch the Mac's ADB
server, change the Mac's SDKs, or install an emulator.
