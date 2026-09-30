package lberrios.pgntrainingreader

import android.net.Uri
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val externalSourceChannel = "lberrios.pgntrainingreader/external_source"
    private val maxRangeBytes = 64 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, externalSourceChannel)
            .setMethodCallHandler { call, result ->
                val uriText = call.argument<String>("uri")
                val uri = parseContentUri(uriText)
                if (uri == null) {
                    result.error("external_uri_invalid", "Only content URIs are supported.", null)
                    return@setMethodCallHandler
                }
                thread(name = "pgn-external-source") {
                    try {
                        val value: Any? = when (call.method) {
                            "length" -> withSeekableDescriptor(uri) { _, stream ->
                                stream.channel.size()
                            }
                            "modifiedAtMicros" -> readModifiedAt(uri)
                            "readRange" -> {
                                val start = call.argument<Number>("start")?.toLong()
                                val end = call.argument<Number>("endExclusive")?.toLong()
                                if (start == null || end == null || start < 0 || end < start ||
                                    end - start > maxRangeBytes
                                ) {
                                    throw SourceAccessException(
                                        "external_range_invalid",
                                        "The requested document range is invalid.",
                                    )
                                }
                                readRange(uri, start, end)
                            }
                            else -> throw SourceAccessException(
                                "external_method_unsupported",
                                "The document operation is not supported.",
                            )
                        }
                        runOnUiThread { result.success(value) }
                    } catch (error: SourceAccessException) {
                        runOnUiThread { result.error(error.code, error.message, null) }
                    } catch (_: SecurityException) {
                        runOnUiThread {
                            result.error("external_source_permission", "The saved document permission is unavailable.", null)
                        }
                    } catch (_: Exception) {
                        runOnUiThread {
                            result.error("external_source_unavailable", "The document could not be read safely.", null)
                        }
                    }
                }
            }
    }

    private fun parseContentUri(value: String?): Uri? {
        val uri = value?.let { runCatching { Uri.parse(it) }.getOrNull() } ?: return null
        return uri.takeIf {
            it.scheme == "content" &&
                !it.authority.isNullOrBlank() &&
                it.encodedAuthority?.contains('@') != true
        }
    }

    private fun <T> withSeekableDescriptor(uri: Uri, action: (ParcelFileDescriptor, FileInputStream) -> T): T {
        if (checkUriPermission(uri, android.os.Process.myPid(), android.os.Process.myUid(),
                android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("No read grant for document.")
        }
        val descriptor = contentResolver.openFileDescriptor(uri, "r")
            ?: throw SourceAccessException("external_source_missing", "The document is unavailable.")
        descriptor.use { pfd ->
            FileInputStream(pfd.fileDescriptor).use { stream ->
                val channel = stream.channel
                val size = try {
                    channel.size()
                } catch (_: Exception) {
                    -1L
                }
                if (size < 0) throw SourceAccessException(
                    "external_source_not_seekable",
                    "The document provider does not expose a seekable source.",
                )
                try {
                    channel.position(0)
                } catch (_: Exception) {
                    throw SourceAccessException(
                        "external_source_not_seekable",
                        "The document provider does not expose a seekable source.",
                    )
                }
                return action(pfd, stream)
            }
        }
    }

    private fun readRange(uri: Uri, start: Long, end: Long): ByteArray =
        withSeekableDescriptor(uri) { _, stream ->
            val channel = stream.channel
            val size = channel.size()
            if (end > size) throw SourceAccessException(
                "external_range_out_of_bounds",
                "The requested range is outside the document.",
            )
            try {
                channel.position(start)
            } catch (_: Exception) {
                throw SourceAccessException(
                    "external_source_not_seekable",
                    "The document provider does not expose a seekable source.",
                )
            }
            val bytes = ByteArray((end - start).toInt())
            val buffer = ByteBuffer.wrap(bytes)
            while (buffer.hasRemaining()) {
                if (channel.read(buffer) < 0) throw SourceAccessException(
                    "external_range_short_read",
                    "The document changed during the read.",
                )
            }
            bytes
        }

    private fun readModifiedAt(uri: Uri): Long? {
        if (checkUriPermission(uri, android.os.Process.myPid(), android.os.Process.myUid(),
                android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) throw SecurityException("No read grant for document.")
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val column = cursor.getColumnIndex("last_modified")
                if (column >= 0 && cursor.moveToFirst() && !cursor.isNull(column)) {
                    cursor.getLong(column) * 1000L
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private class SourceAccessException(val code: String, override val message: String) : Exception(message)
}
