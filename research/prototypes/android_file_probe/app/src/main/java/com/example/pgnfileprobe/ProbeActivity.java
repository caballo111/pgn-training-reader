package com.example.pgnfileprobe;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;

/** Disposable T008 probe; do not copy into the production app. */
public final class ProbeActivity extends Activity {
  private static final int REQUEST_OPEN_DOCUMENT = 1001;
  private static final String TAG = "PgnFileProbe";

  @Override
  protected void onCreate(Bundle state) {
    super.onCreate(state);
    openPicker();
  }

  private void openPicker() {
    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
    intent.addCategory(Intent.CATEGORY_OPENABLE);
    intent.setType("application/octet-stream");
    intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/x-chess-pgn", "text/plain"});
    startActivityForResult(intent, REQUEST_OPEN_DOCUMENT);
  }

  @Override
  protected void onActivityResult(int requestCode, int resultCode, Intent data) {
    super.onActivityResult(requestCode, resultCode, data);
    if (requestCode != REQUEST_OPEN_DOCUMENT || resultCode != RESULT_OK || data == null) return;
    Uri uri = data.getData();
    if (uri == null) return;
    int flags = data.getFlags() &
        (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
    boolean persisted = false;
    try {
      getContentResolver().takePersistableUriPermission(uri, flags & Intent.FLAG_GRANT_READ_URI_PERMISSION);
      persisted = true;
    } catch (RuntimeException ignored) {
      // A provider may grant a transient read permission only.
    }
    logProbe(uri, persisted);
  }

  private void logProbe(Uri uri, boolean persisted) {
    long length = -1;
    boolean seekable = false;
    String firstRange = "unread";
    String secondRange = "unread";
    try (ParcelFileDescriptor descriptor = getContentResolver().openFileDescriptor(uri, "r")) {
      if (descriptor == null) throw new IOException("null descriptor");
      length = descriptor.getStatSize();
      try (FileInputStream input = new FileInputStream(descriptor.getFileDescriptor())) {
        FileChannel channel = input.getChannel();
        channel.position(0);
        seekable = channel.position() == 0;
        firstRange = readRange(channel, 0, 32);
        secondRange = length >= 64 ? readRange(channel, length - 32, 32) : "file shorter than 64 bytes";
      }
    } catch (IOException | RuntimeException error) {
      Log.i(TAG, "probe_error=" + error.getClass().getSimpleName() + ":" + error.getMessage());
    }
    Log.i(TAG, "authority=" + uri.getAuthority());
    Log.i(TAG, "uri=" + uri);
    Log.i(TAG, "persisted_permission=" + persisted);
    Log.i(TAG, "length=" + length);
    Log.i(TAG, "seekable=" + seekable);
    Log.i(TAG, "first_range=" + firstRange);
    Log.i(TAG, "second_range=" + secondRange);
  }

  private static String readRange(FileChannel channel, long offset, int count) throws IOException {
    channel.position(offset);
    ByteBuffer buffer = ByteBuffer.allocate(count);
    int read = channel.read(buffer);
    return "offset=" + offset + ",requested=" + count + ",read=" + read;
  }
}
