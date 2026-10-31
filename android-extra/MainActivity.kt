package de.papiertiger.tiger.papiertiger

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.speech.RecognizerIntent
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
    private var diktatErgebnis: MethodChannel.Result? = null

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
                "diktieren" -> diktieren(result)
                "mailSenden" -> result.success(
                    mailSenden(
                        call.argument<String>("an") ?: "",
                        call.argument<String>("betreff") ?: "",
                        call.argument<String>("text") ?: "",
                        call.argument<List<String>>("pfade") ?: emptyList(),
                    )
                )
                "datenschluessel" -> try {
                    result.success(datenschluessel())
                } catch (e: Exception) {
                    result.error("schluessel", e.toString(), null)
                }
                "bildschirmschutz" -> {
                    if (call.argument<Boolean>("an") == true) {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                "geraetGesichert" -> result.success(
                    (getSystemService(KEYGUARD_SERVICE) as android.app.KeyguardManager).isDeviceSecure
                )
                "geraetEntsperren" -> geraetEntsperren(result)
                "appOeffnen" -> result.success(appOeffnen(call.argument<List<String>>("pakete") ?: emptyList()))
                "widget" -> {
                    val mgr = android.appwidget.AppWidgetManager.getInstance(this)
                    val ids = mgr.getAppWidgetIds(android.content.ComponentName(this, PapiertigerWidget::class.java))
                    if (ids.isNotEmpty()) {
                        sendBroadcast(
                            Intent(this, PapiertigerWidget::class.java)
                                .setAction(android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                                .putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        )
                    }
                    result.success(ids.size)
                }
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
    /**
     * E-Mail mit Anhängen: öffnet nur E-Mail-Apps, Empfänger, Betreff, Text und Dateien sind
     * eingetragen. Verschickt wird erst, wenn du dort auf Senden tippst.
     */
    private fun mailSenden(an: String, betreff: String, text: String, pfade: List<String>): Boolean {
        val ordner = File(cacheDir, "senden")
        ordner.mkdirs()
        val uris = ArrayList<Uri>()
        for (p in pfade) {
            val quelle = File(p)
            if (!quelle.exists()) continue
            val ziel = File(ordner, quelle.name)
            quelle.copyTo(ziel, overwrite = true)
            uris.add(androidx.core.content.FileProvider.getUriForFile(this, "$packageName.dateien", ziel))
        }
        val intent = if (uris.size > 1) {
            Intent(Intent.ACTION_SEND_MULTIPLE).apply { putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris) }
        } else {
            Intent(Intent.ACTION_SEND).apply { if (uris.isNotEmpty()) putExtra(Intent.EXTRA_STREAM, uris[0]) }
        }
        intent.type = when {
            uris.isEmpty() -> "text/plain"
            uris.size == 1 && pfade.firstOrNull()?.endsWith(".pdf") == true -> "application/pdf"
            else -> "*/*"
        }
        if (an.isNotBlank()) intent.putExtra(Intent.EXTRA_EMAIL, arrayOf(an))
        intent.putExtra(Intent.EXTRA_SUBJECT, betreff)
        intent.putExtra(Intent.EXTRA_TEXT, text)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (uris.isNotEmpty()) {
            val clip = android.content.ClipData.newUri(contentResolver, "Anhang", uris[0])
            for (u in uris.drop(1)) clip.addItem(android.content.ClipData.Item(u))
            intent.clipData = clip
        }
        // Nur E-Mail-Apps anbieten
        intent.selector = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
        return try {
            startActivity(Intent.createChooser(intent, "E-Mail senden mit …").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Öffnet die erste installierte App aus der Liste (z. B. Sparkasse). */
    private fun appOeffnen(pakete: List<String>): Boolean {
        for (p in pakete) {
            val i = packageManager.getLaunchIntentForPackage(p) ?: continue
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return try {
                startActivity(i)
                true
            } catch (e: Exception) {
                false
            }
        }
        return false
    }

    /**
     * Schlüssel für die Datenverschlüsselung der App. Er wird zufällig erzeugt und mit einem Schlüssel
     * aus dem Android-Keystore (Sicherheitschip) verschlüsselt abgelegt – er verlässt das Gerät nie.
     */
    private fun datenschluessel(): String {
        val alias = "papiertiger_daten"
        val ks = java.security.KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!ks.containsAlias(alias)) {
            val gen = javax.crypto.KeyGenerator.getInstance(
                android.security.keystore.KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
            )
            gen.init(
                android.security.keystore.KeyGenParameterSpec.Builder(
                    alias,
                    android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or
                        android.security.keystore.KeyProperties.PURPOSE_DECRYPT
                )
                    .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build()
            )
            gen.generateKey()
        }
        val haupt = (ks.getEntry(alias, null) as java.security.KeyStore.SecretKeyEntry).secretKey
        val sp = getSharedPreferences("papiertiger_sicher", MODE_PRIVATE)
        val gespeichert = sp.getString("schluessel", null)
        if (gespeichert != null) {
            val roh = android.util.Base64.decode(gespeichert, android.util.Base64.NO_WRAP)
            val c = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
            c.init(javax.crypto.Cipher.DECRYPT_MODE, haupt, javax.crypto.spec.GCMParameterSpec(128, roh.copyOfRange(0, 12)))
            return android.util.Base64.encodeToString(c.doFinal(roh.copyOfRange(12, roh.size)), android.util.Base64.NO_WRAP)
        }
        val neu = ByteArray(32).also { java.security.SecureRandom().nextBytes(it) }
        val c = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
        c.init(javax.crypto.Cipher.ENCRYPT_MODE, haupt)
        val verpackt = c.iv + c.doFinal(neu)
        sp.edit().putString("schluessel", android.util.Base64.encodeToString(verpackt, android.util.Base64.NO_WRAP)).commit()
        return android.util.Base64.encodeToString(neu, android.util.Base64.NO_WRAP)
    }

    private var entsperrErgebnis: MethodChannel.Result? = null

    /** Entsperren mit der Displaysperre des Handys (PIN, Muster, Fingerabdruck). */
    private fun geraetEntsperren(result: MethodChannel.Result) {
        val km = getSystemService(KEYGUARD_SERVICE) as android.app.KeyguardManager
        @Suppress("DEPRECATION")
        val i = km.createConfirmDeviceCredentialIntent("Papiertiger entsperren", "Mit deiner Displaysperre")
        if (i == null) {
            result.success(false)
            return
        }
        entsperrErgebnis?.success(false)
        entsperrErgebnis = result
        @Suppress("DEPRECATION")
        startActivityForResult(i, ENTSPERREN)
    }

    /** Spracheingabe des Systems: zeigt das Mikrofon-Fenster, liefert den erkannten Text (oder null). */
    private fun diktieren(result: MethodChannel.Result) {
        diktatErgebnis?.success(null)
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "de-DE")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Sprich jetzt – der Tiger schreibt mit")
        }
        try {
            diktatErgebnis = result
            @Suppress("DEPRECATION")
            startActivityForResult(i, DIKTAT)
        } catch (e: ActivityNotFoundException) {
            diktatErgebnis = null
            result.error("keine_spracheingabe", "Keine Spracheingabe auf diesem Gerät", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ENTSPERREN) {
            entsperrErgebnis?.success(resultCode == android.app.Activity.RESULT_OK)
            entsperrErgebnis = null
            return
        }
        if (requestCode != DIKTAT) return
        val r = diktatErgebnis ?: return
        diktatErgebnis = null
        val text = if (resultCode == android.app.Activity.RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        } else null
        r.success(text)
    }

    companion object {
        private const val DIKTAT = 4711
        private const val ENTSPERREN = 4712
    }
}
