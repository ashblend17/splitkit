package com.example.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/**
 * "₹450 at Swiggy · HDFC ··4821", with Split. Tapping opens the entry; Split opens Add split
 * with the payment filled in. The intent carries the message itself (SmsChannel "takeLaunch"),
 * which the app reads and adds before opening it.
 *
 * A locked phone shows "A payment from your bank" instead, with no amount, merchant or Split,
 * unless you chose to show amounts there (spec §5.7).
 */
object SmsNotifier {
    private const val CHANNEL = "bank_messages"

    fun show(context: Context, sms: Map<String, Any>, described: Map<*, *>, splitAction: Boolean, lockScreenAmounts: Boolean) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Bank messages", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "A payment your bank told you about, to check or split"
                },
            )
        }
        val id = "${sms["address"]}|${sms["body"]}".hashCode()
        fun open(action: String, code: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                this.action = "${context.packageName}.SMS_${action.uppercase()}"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(MainActivity.SMS_ADDRESS, sms["address"] as String)
                putExtra(MainActivity.SMS_BODY, sms["body"] as String)
                putExtra(MainActivity.SMS_DATE, sms["date"] as Long)
                putExtra(MainActivity.SMS_ACTION, action)
                putExtra(MainActivity.SMS_NOTIFICATION, id)
            }
            val immutable = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getActivity(context, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or immutable)
        }
        @Suppress("DEPRECATION")
        fun builder() = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        // What a locked phone shows unless amounts may show there.
        val hidden = builder().setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle("A payment from your bank")
            .setContentText("Unlock to see it")
            .setAutoCancel(true)
            .setContentIntent(open("open", id))
            .build()
        val builder = builder()
        builder.setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(described["title"] as? String ?: "A bank payment")
            .setContentText(described["text"] as? String ?: "")
            .setAutoCancel(true)
            .setContentIntent(open("open", id))
            .setVisibility(if (lockScreenAmounts) Notification.VISIBILITY_PUBLIC else Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(hidden)
        if (splitAction && described["split"] == true) {
            @Suppress("DEPRECATION")
            builder.addAction(Notification.Action.Builder(0, "Split", open("split", id + 1)).build())
        }
        manager.notify(id, builder.build())
    }

    fun cancel(context: Context, id: Int) {
        context.getSystemService(NotificationManager::class.java)?.cancel(id)
    }
}
