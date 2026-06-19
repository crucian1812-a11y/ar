package com.example.booktracker.ocr

import android.content.Context
import android.graphics.Bitmap
import com.googlecode.tesseract.android.TessBaseAPI
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Offline OCR powered by Tesseract. Language data ("rus", "eng") is downloaded
 * on first use into the app's files dir, so no large binaries ship in the repo.
 */
class OcrManager(private val context: Context) {

    private val languages = listOf("rus", "eng")
    private val tessLang = languages.joinToString("+")

    private val tessdataDir: File
        get() = File(context.filesDir, "tessdata").apply { mkdirs() }

    fun isReady(): Boolean = languages.all { File(tessdataDir, "$it.traineddata").exists() }

    /** Downloads any missing language files. [onProgress] receives a 0f..1f-ish hint. */
    suspend fun ensureLanguages(onProgress: (String) -> Unit = {}): Result<Unit> =
        withContext(Dispatchers.IO) {
            runCatching {
                for (lang in languages) {
                    val target = File(tessdataDir, "$lang.traineddata")
                    if (target.exists() && target.length() > 0) continue
                    onProgress("Загрузка языка: $lang…")
                    val url = URL(
                        "https://github.com/tesseract-ocr/tessdata_fast/raw/main/$lang.traineddata"
                    )
                    val tmp = File(tessdataDir, "$lang.traineddata.part")
                    (url.openConnection() as HttpURLConnection).run {
                        connectTimeout = 20_000
                        readTimeout = 60_000
                        instanceFollowRedirects = true
                        inputStream.use { input ->
                            tmp.outputStream().use { output -> input.copyTo(output) }
                        }
                        disconnect()
                    }
                    if (!tmp.renameTo(target)) {
                        tmp.copyTo(target, overwrite = true)
                        tmp.delete()
                    }
                }
            }
        }

    suspend fun recognize(bitmap: Bitmap): Result<String> = withContext(Dispatchers.Default) {
        runCatching {
            val tess = TessBaseAPI()
            try {
                check(tess.init(context.filesDir.absolutePath, tessLang)) {
                    "Не удалось инициализировать Tesseract"
                }
                tess.setImage(bitmap)
                tess.getUTF8Text().orEmpty().trim()
            } finally {
                tess.recycle()
            }
        }
    }
}
