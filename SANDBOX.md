# Local Codex sandbox

The environment is defined in `sbxenv.yaml`; `.sbx/setup-flutter.sh` adds
Flutter 3.47.5 after sandbox creation, matching `.fvmrc`. Flutter and Dart are installed inside the
sandbox. The project directory is shared with the host; edits are visible in
both places. SBX mounts the environment file read-only inside the sandbox.

From this project directory:

```sh
sbx env create --auto-approve .
sbx env run .
sbx env exec . -- flutter --version
sbx env exec . -- flutter doctor -v
sbx env exec . -- flutter test
```

Use `flutter` and `dart` directly inside this environment; its SDK is pinned by
the setup script, so FVM is not required there. When changing the Flutter version, update
both `.fvmrc` and the script and recreate the sandbox.

The post-create hook runs `sbx exec` on the host to install tools inside the
sandbox. This avoids a hang observed with SBX 0.45.1 kit install hooks. To
rerun the setup in an existing sandbox:

```sh
sbx exec pgn-training-reader bash .sbx/setup-flutter.sh
```

ChatGPT authentication is handled by SBX on the host using the global OpenAI
OAuth credential in the OS keychain. Do not run `codex login` inside the sandbox.
The proxy can make `codex login status` report API-key authentication even when
the host uses OAuth. The credential is not stored in the project.

The Android phone and its PGN files remain outside the sandbox. Keep wireless
ADB pairing and deployment on the host. This environment currently installs
Flutter's Android engine artifacts; a full Android SDK is a separate prerequisite
for building APKs inside it. Do not mount or copy the phone's PGN files here.

To stop or remove this project's sandbox:

```sh
sbx stop pgn-training-reader
sbx env rm --force .
```

Removal retains project files and the global OAuth credential.

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
