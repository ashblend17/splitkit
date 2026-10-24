package com.example.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * A new SMS, with the app closed or in the background: if it's from a bank sender and you
 * want notifications, the app's own parser (in a short-lived Dart engine, SmsBackground)
 * describes it and SmsNotifier shows "₹450 at Swiggy" with Split. Nothing is stored here: when
 * you open the app it reads the inbox as always.
 *
 * With the app in front, nothing happens here: the app sees the inbox change and reads it.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val config = SmsConfig.read(context)
        if (!config.notify || MainActivity.resumed) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        // One SMS can arrive in parts: join them by sender.
        val messages = parts.groupBy { it.originatingAddress ?: "" }.mapNotNull { (address, pieces) ->
            if (!config.senders.matches(address)) return@mapNotNull null
            mapOf(
                "address" to address,
                "body" to pieces.joinToString("") { it.messageBody ?: "" },
                "date" to System.currentTimeMillis(),
            )
        }
        if (messages.isEmpty()) return
        val pending = goAsync()
        var left = messages.size
        for (sms in messages) {
            SmsBackground.describe(context, sms) { described ->
                if (described != null) SmsNotifier.show(context, sms, described, config.splitAction, config.lockScreenAmounts)
                if (--left == 0) pending.finish()
            }
        }
    }
}

/** What the app told the phone (SmsChannel "configure"), kept for the receiver. */
data class SmsConfig(val notify: Boolean, val splitAction: Boolean, val lockScreenAmounts: Boolean, val senders: Regex) {
    companion object {
        private const val PREFS = "sms_config" // the app rewrites it each time it reads the inbox

        fun read(context: Context): SmsConfig {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return SmsConfig(
                notify = p.getBoolean("notify", false),
                splitAction = p.getBoolean("split", true),
                lockScreenAmounts = p.getBoolean("amounts", false),
                senders = Regex(p.getString("senders", null) ?: "(?!)"),
            )
        }

        fun write(context: Context, notify: Boolean, splitAction: Boolean, lockScreenAmounts: Boolean, senders: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("notify", notify)
                .putBoolean("split", splitAction)
                .putBoolean("amounts", lockScreenAmounts)
                .putString("senders", senders)
                .apply()
        }
    }
}
