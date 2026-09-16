# Android document-provider probe

This is a disposable manual spike for T008. It is deliberately outside the
Flutter application. `ProbeActivity.java` opens an `ACTION_OPEN_DOCUMENT`
stream, requests persistable access, checks `AssetFileDescriptor` length,
attempts a seek, and reads two byte ranges. The same PGN must be selected from
two providers, recording the provider authority and every observed result.

## Procedure

1. Install the small probe activity on the reference Android device.
2. Put the same UTF-8 PGN fixture in two provider-backed locations. The
   baseline providers are Android Downloads (`com.android.providers.downloads.documents`)
   and Media/Documents (`com.android.providers.media.documents`); test Google
   Drive as a third provider when available.
3. Select the file with `ACTION_OPEN_DOCUMENT` and record:
   - URI authority and whether `takePersistableUriPermission` succeeds;
   - reported length from `AssetFileDescriptor` and `ParcelFileDescriptor`;
   - whether `lseek`/`FileChannel.position` succeeds;
   - whether two non-overlapping range reads return the expected bytes;
   - whether the same URI still opens after process restart and device restart.
4. Repeat for the second provider. Re-run after changing the source file to
   confirm that the fingerprint detects the change.

The probe must not conclude that offsets are reliable when a provider only
returns a stream. A provider with no stable length, seek, or repeatable range
read is classified as `stream-only` and must use the managed-copy path.

## Environment result

The probe was built and installed on the Pixel 9 emulator (`emulator-5554`)
on 2026-09-15. Both tested locations reported successful persistable access,
235-byte length, seekability, and complete 32-byte reads at offsets 0 and 203:

| Location | Provider authority |
| --- | --- |
| Downloads | `com.android.providers.downloads.documents` |
| Shared storage/Documents | `com.android.externalstorage.documents` |

This result is specific to these providers and this emulator image. Providers
that fail any of these checks must use managed-copy import.
