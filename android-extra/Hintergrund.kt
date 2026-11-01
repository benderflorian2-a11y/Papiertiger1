package de.papiertiger.tiger.papiertiger

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Schlüssel für die Datenverschlüsselung der App. Er wird zufällig erzeugt und mit einem Schlüssel
 * aus dem Android-Keystore (Sicherheitschip) verschlüsselt abgelegt – er verlässt das Gerät nie.
 */
fun datenschluessel(ctx: Context): String {
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
    val sp = ctx.getSharedPreferences("papiertiger_sicher", Context.MODE_PRIVATE)
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


/**
 * Sieht im Hintergrund im verknüpften E-Mail-Postfach nach: startet den Dart-Teil `mailHintergrund`
 * ohne Bildschirm und wartet, bis er fertig ist. Liest nur, verschickt nie.
 */
class MailPruefung(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val fertig = CountDownLatch(1)
        val haupt = Handler(Looper.getMainLooper())
        var engine: FlutterEngine? = null
        haupt.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val e = FlutterEngine(applicationContext)
                MethodChannel(e.dartExecutor.binaryMessenger, "papiertiger/android").setMethodCallHandler { call, result ->
                    when (call.method) {
                        "datenschluessel" -> try {
                            result.success(datenschluessel(applicationContext))
                        } catch (x: Exception) {
                            result.error("schluessel", x.toString(), null)
                        }
                        "mailFertig" -> {
                            result.success(true)
                            fertig.countDown()
                        }
                        else -> result.notImplemented()
                    }
                }
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "mailHintergrund")
                )
                engine = e
            } catch (x: Exception) {
                fertig.countDown()
            }
        }
        fertig.await(4, TimeUnit.MINUTES)
        haupt.post { engine?.destroy() }
        return Result.success()
    }

    companion object {
        private const val NAME = "mailpruefung"

        fun planen(ctx: Context, an: Boolean) {
            val wm = WorkManager.getInstance(ctx)
            if (!an) {
                wm.cancelUniqueWork(NAME)
                return
            }
            val anfrage = PeriodicWorkRequestBuilder<MailPruefung>(30, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            wm.enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.UPDATE, anfrage)
        }
    }
}
