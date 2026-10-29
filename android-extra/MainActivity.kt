package de.papiertiger.tiger.papiertiger

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Papiertiger: empfängt Inhalte aus „Teilen“ (E-Mails, PDFs, Bilder, Text)
 * und öffnet E-Mail-, Telefon- und Web-Links. Verschickt oder wählt nie selbst.
 */
class MainActivity : FlutterActivity() {
    private var geteilt: List<Map<String, String?>> = emptyList()
    private var kanal: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        geteilt = lesen(intent)
        val k = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "papiertiger/android")
        k.setMethodCallHandler { call, result ->
            when (call.method) {
                "geteilt" -> {
                    result.success(geteilt)
                    geteilt = emptyList()
                }
                "oeffnen" -> result.success(oeffnen(call.argument<String>("uri") ?: ""))
                else -> result.notImplemented()
            }
        }
        kanal = k
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val neu = lesen(intent)
        if (neu.isNotEmpty()) {
            geteilt = neu
            kanal?.invokeMethod("neu", null)
        }
    }

    private fun lesen(intent: Intent?): List<Map<String, String?>> {
        if (intent == null) return emptyList()
        val out = mutableListOf<Map<String, String?>>()
        try {
            when (intent.action) {
                Intent.ACTION_SEND -> {
                    val uri = stream(intent)
                    if (uri != null) {
                        kopieren(uri, intent.type)?.let { out.add(it) }
                    } else {
                        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                        if (!text.isNullOrBlank()) {
                            out.add(mapOf("text" to text, "betreff" to intent.getStringExtra(Intent.EXTRA_SUBJECT)))
                        }
                    }
                }
                Intent.ACTION_SEND_MULTIPLE -> {
                    for (uri in streams(intent)) kopieren(uri, intent.type)?.let { out.add(it) }
                }
                Intent.ACTION_VIEW -> {
                    val uri = intent.data
                    if (uri != null && (uri.scheme == "content" || uri.scheme == "file")) {
                        kopieren(uri, intent.type)?.let { out.add(it) }
                    }
                }
            }
        } catch (e: Exception) {
            // Nicht lesbar: dann eben nichts übernehmen.
        }
        if (out.isNotEmpty()) intent.action = null
        return out
    }

    private fun stream(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    private fun streams(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        }) ?: arrayListOf()

    private fun name(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getString(0)
                    if (!n.isNullOrBlank()) return n
                }
            }
        } catch (e: Exception) {
        }
        return uri.lastPathSegment ?: "datei"
    }

    private fun kopieren(uri: Uri, typ: String?): Map<String, String?>? {
        val name = name(uri).replace(Regex("[^A-Za-z0-9ÄÖÜäöüß._ -]"), "_")
        val ordner = File(cacheDir, "geteilt")
        ordner.mkdirs()
        val ziel = File(ordner, "${System.currentTimeMillis()}_$name")
        val ok = contentResolver.openInputStream(uri)?.use { ein ->
            ziel.outputStream().use { aus -> ein.copyTo(aus) }
            true
        } ?: false
        if (!ok) return null
        val mime = contentResolver.getType(uri) ?: typ
        return mapOf("pfad" to ziel.absolutePath, "mime" to mime, "name" to name)
    }

    /** mailto: ist eine „undurchsichtige“ URI, deshalb Parameter von Hand lesen. */
    private fun mailtoParameter(uri: Uri): Map<String, String> {
        val teil = uri.encodedSchemeSpecificPart ?: return emptyMap()
        val i = teil.indexOf('?')
        if (i < 0) return emptyMap()
        return teil.substring(i + 1).split('&').mapNotNull { p ->
            val j = p.indexOf('=')
            if (j <= 0) null else p.substring(0, j).lowercase() to (Uri.decode(p.substring(j + 1)) ?: "")
        }.toMap()
    }

    private fun oeffnen(s: String): Boolean {
        val uri = Uri.parse(s)
        val intent = when (uri.scheme) {
            "tel" -> Intent(Intent.ACTION_DIAL, uri)
            "mailto" -> Intent(Intent.ACTION_SENDTO, uri).apply {
                // Manche E-Mail-Apps lesen Betreff und Text nur aus den Extras.
                val q = mailtoParameter(uri)
                q["subject"]?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
                q["body"]?.let { putExtra(Intent.EXTRA_TEXT, it) }
            }
            else -> Intent(Intent.ACTION_VIEW, uri)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }
}
