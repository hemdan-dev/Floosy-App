package net.floosy.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "net.floosy.app/capture"
        ).setMethodCallHandler { call, result ->
            if (call.method != "consumePendingSms") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val preferences = getSharedPreferences(SmsReceiver.PREFERENCES, MODE_PRIVATE)
            val raw = preferences.getString(SmsReceiver.PENDING_KEY, "[]") ?: "[]"
            val array = JSONArray(raw)
            val messages = mutableListOf<Map<String, String>>()
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                messages.add(
                    mapOf(
                        "sender" to item.optString("sender"),
                        "body" to item.optString("body"),
                        "fingerprint" to item.optString("fingerprint"),
                    )
                )
            }
            preferences.edit().putString(SmsReceiver.PENDING_KEY, "[]").apply()
            result.success(messages)
        }
    }
}
