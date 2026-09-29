package com.example.fe

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Icona dell'app che segue il tema StudentLab.
 *
 * Nel manifest c'è un activity-alias per tema (".LauncherNotte",
 * ".LauncherTerra", …), attivo uno alla volta. Flutter chiede il cambio quando
 * l'utente esce dall'app, così il sistema non chiude l'app mentre la usa.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "studentlab/app_icon"
    private val icons = listOf("notte", "ardesia", "terra", "bosco", "pietra", "fico", "torbiera", "focus", "argilla", "kiwi", "pesca", "antartide", "cocco", "laguna")

    // Gli alias sono dichiarati come ".LauncherX": il nome completo usa il
    // pacchetto delle classi (namespace), l'app è identificata da packageName.
    private val aliasPrefix = MainActivity::class.java.name.substringBeforeLast('.')

    private fun component(id: String) =
        ComponentName(packageName, "$aliasPrefix.Launcher${id.replaceFirstChar { it.uppercase() }}")

    private fun isEnabled(id: String): Boolean {
        val state = packageManager.getComponentEnabledSetting(component(id))
        return when (state) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            // Stato di default: quello scritto nel manifest (solo Notte è attivo).
            else -> id == "notte"
        }
    }

    private fun current(): String = icons.firstOrNull { isEnabled(it) } ?: "notte"

    private fun apply(id: String) {
        if (id !in icons) throw IllegalArgumentException("Icona sconosciuta: $id")
        if (current() == id) return
        val pm = packageManager
        // Prima si attiva la nuova, poi si spengono le altre: il launcher non
        // resta mai senza un ingresso per l'app.
        pm.setComponentEnabledSetting(
            component(id),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (other in icons) {
            if (other == id) continue
            pm.setComponentEnabledSetting(
                component(other),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "current" -> result.success(current())
                    "set" -> {
                        apply(call.argument<String>("id") ?: "notte")
                        result.success(current())
                    }
                    "sdk" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("app_icon", error.message, null)
            }
        }
    }
}
