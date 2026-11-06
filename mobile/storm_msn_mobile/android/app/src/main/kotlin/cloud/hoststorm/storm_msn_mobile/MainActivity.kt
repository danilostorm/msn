package cloud.hoststorm.storm_msn_mobile

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val filePickerRequest = 9046
    private var pendingFileResult: MethodChannel.Result? = null
    private val maxAttachmentBytes = 8 * 1024 * 1024

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != filePickerRequest) return
        val answer = pendingFileResult ?: return
        pendingFileResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            answer.success(null)
            return
        }
        try {
            val uri = data.data!!
            var name = "arquivo"
            var expectedSize: Long? = null
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        name = cursor.getString(nameIndex) ?: "arquivo"
                    }
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        expectedSize = cursor.getLong(sizeIndex)
                    }
                }
            }
            val supported = setOf(
                "png", "jpg", "jpeg", "gif", "webp", "pdf",
                "txt", "zip", "docx", "xlsx"
            )
            val extension = name.substringAfterLast('.', "").lowercase()
            if (!supported.contains(extension)) {
                answer.error("FILE_TYPE", "Formato de arquivo não permitido.", null)
                return
            }
            if (expectedSize != null && expectedSize!! > maxAttachmentBytes) {
                answer.error("TOO_LARGE", "Arquivo maior que 8 MB.", null)
                return
            }
            val output = ByteArrayOutputStream()
            val dataChunk = ByteArray(16 * 1024)
            val stream = contentResolver.openInputStream(uri)
            if (stream == null) {
                answer.error("READ_FILE", "Não foi possível abrir o arquivo.", null)
                return
            }
            stream.use { input ->
                while (true) {
                    val bytesRead = input.read(dataChunk)
                    if (bytesRead < 0) break
                    if (output.size() + bytesRead > maxAttachmentBytes) {
                        answer.error("TOO_LARGE", "Arquivo maior que 8 MB.", null)
                        return
                    }
                    output.write(dataChunk, 0, bytesRead)
                }
            }
            answer.success(mapOf("name" to name, "bytes" to output.toByteArray()))
        } catch (error: Exception) {
            answer.error("READ_FILE", "Falha ao ler o anexo.", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cloud.hoststorm.storm_msn_mobile/attachments"
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickAttachment") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingFileResult != null) {
                result.error("PICKER_BUSY", "Outro seletor está aberto.", null)
                return@setMethodCallHandler
            }
            val chooser = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                    "image/jpeg", "image/png", "image/gif", "image/webp",
                    "application/pdf", "text/plain", "application/zip",
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                ))
            }
            pendingFileResult = result
            try {
                startActivityForResult(chooser, filePickerRequest)
            } catch (error: Exception) {
                pendingFileResult = null
                result.error("PICKER_UNAVAILABLE", "Seletor indisponível.", null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cloud.hoststorm.storm_msn_mobile/preferences"
        ).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("storm_msn_mobile", MODE_PRIVATE)
            when (call.method) {
                "loadEmail" -> result.success(prefs.getString("email", null))
                "saveEmail" -> {
                    prefs.edit().putString("email", call.argument<String>("email") ?: "").apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cloud.hoststorm.storm_msn_mobile/navigation"
        ).setMethodCallHandler { call, result ->
            if (call.method != "openBrowser") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val text = call.argument<String>("url") ?: ""
            val uri = Uri.parse(text)
            val allowed = uri.scheme == "https" && (
                uri.host == "msn.hoststorm.com.br" ||
                uri.host == "playstor.hoststorm.cloud"
            )
            if (!allowed) {
                result.error("DOMAIN_BLOCKED", "Domínio não autorizado.", null)
                return@setMethodCallHandler
            }
            try {
                startActivity(Intent(Intent.ACTION_VIEW, uri))
                result.success(null)
            } catch (_: Exception) {
                result.error("NO_BROWSER", "Nenhum navegador disponível.", null)
            }
        }
    }
}
