package com.splitkit.splitkit

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var sms: SmsChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        fromNotification(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        fromNotification(intent)
    }

    override fun onResume() {
        super.onResume()
        resumed = true
    }

    override fun onPause() {
        resumed = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sms = SmsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sms?.dispose()
        sms = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        sms?.onPermissionResult(requestCode, grantResults)
    }

    /** A bank SMS notification was tapped (SmsNotifier): keep its message for the app. */
    private fun fromNotification(intent: Intent?) {
        val body = intent?.getStringExtra(SMS_BODY) ?: return
        SmsChannel.launch = mapOf(
            "address" to (intent.getStringExtra(SMS_ADDRESS) ?: ""),
            "body" to body,
            "date" to intent.getLongExtra(SMS_DATE, System.currentTimeMillis()),
            "action" to (intent.getStringExtra(SMS_ACTION) ?: "open"),
            "notification" to intent.getIntExtra(SMS_NOTIFICATION, 0),
        )
        intent.removeExtra(SMS_BODY) // not again on a configuration change
    }

    companion object {
        /** In front: the app reads new SMS itself, so the receiver doesn't notify. */
        @Volatile
        var resumed = false

        const val SMS_ADDRESS = "sms_address"
        const val SMS_BODY = "sms_body"
        const val SMS_DATE = "sms_date"
        const val SMS_ACTION = "sms_action"
        const val SMS_NOTIFICATION = "sms_notification"
    }
}
