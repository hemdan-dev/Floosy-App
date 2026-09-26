package net.floosy.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

class SmsReceiver : BroadcastReceiver() {
    companion object {
        const val PREFERENCES = "floosy_sms_capture"
        const val PENDING_KEY = "pending_messages"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return
        val sender = messages.first().originatingAddress ?: ""
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
        if (body.isBlank()) return

        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$sender|$body".toByteArray())
            .joinToString("") { "%02x".format(it) }
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val pending = JSONArray(preferences.getString(PENDING_KEY, "[]"))
        pending.put(
            JSONObject()
                .put("sender", sender)
                .put("body", body)
                .put("fingerprint", digest)
        )
        preferences.edit().putString(PENDING_KEY, pending.toString()).apply()
    }
}
