package com.example.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bank SMS for the app (lib/features/sms/sms_source.dart).
 *
 * `app/sms` reads the inbox, but only messages whose sender matches the pattern the app
 * passes (business headers such as VM-HDFCBK-S): messages from people never leave this class.
 * `app/sms/live` fires when the inbox changes while the app is open, after the SMS app has
 * stored the message, so a read that follows finds it.
 *
 * It also passes on what the receiver needs for notifications ("configure"), asks for the
 * notification permission, and hands over the message a tapped notification was about
 * ("takeLaunch").
 */
class SmsChannel(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methods = MethodChannel(messenger, "app/sms")
    private val events = EventChannel(messenger, "app/sms/live")
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var observer: ContentObserver? = null

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "access" -> result.success(canRead())
            "request" -> request(result, notifications = call.argument<String>("which") == "notifications")
            "notificationAccess" -> result.success(canNotify())
            "configure" -> {
                SmsConfig.write(
                    activity,
                    notify = call.argument<Boolean>("notify") ?: false,
                    splitAction = call.argument<Boolean>("split") ?: true,
                    lockScreenAmounts = call.argument<Boolean>("amounts") ?: false,
                    senders = call.argument<String>("senders") ?: "(?!)",
                )
                result.success(null)
            }
            "takeLaunch" -> {
                result.success(launch)
                launch = null
            }
            "cancel" -> {
                SmsNotifier.cancel(activity, call.argument<Int>("id") ?: 0)
                result.success(null)
            }
            "settings" -> {
                activity.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null)),
                )
                result.success(null)
            }
            "inbox" -> inbox(
                since = call.argument<Number>("since")?.toLong() ?: 0L,
                senders = call.argument<String>("senders") ?: return result.error("args", "senders missing", null),
                limit = call.argument<Int>("limit") ?: 500,
                result = result,
            )
            else -> result.notImplemented()
        }
    }

    private fun canRead(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            activity.checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    private fun canNotify(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** SMS access (reading, and receiving for notifications), or the notification permission. */
    private fun request(result: MethodChannel.Result, notifications: Boolean) {
        if (if (notifications) canNotify() else canRead() && canReceive()) return result.success(true)
        if (pending != null) return result.error("busy", "Already asking", null)
        pending = result
        val wanted = if (notifications) {
            arrayOf(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS)
        }
        activity.requestPermissions(wanted, REQUEST_CODE)
    }

    private fun canReceive(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            activity.checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    /** From MainActivity.onRequestPermissionsResult: allowed if the first one asked for is. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        pending?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pending = null
    }

    /** Matching messages that arrived at or after [since] (ms), oldest first, at most [limit]. */
    private fun inbox(since: Long, senders: String, limit: Int, result: MethodChannel.Result) {
        if (!canRead()) return result.error("no_access", "Reading SMS isn't allowed", null)
        val pattern = Regex(senders)
        io.execute {
            try {
                val out = ArrayList<Map<String, Any>>()
                activity.contentResolver.query(
                    Telephony.Sms.Inbox.CONTENT_URI,
                    arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                    "${Telephony.Sms.DATE} >= ?",
                    arrayOf(since.toString()),
                    "${Telephony.Sms.DATE} ASC",
                )?.use { c ->
                    while (out.size < limit && c.moveToNext()) {
                        val address = c.getString(0) ?: continue
                        if (!pattern.matches(address)) continue
                        out.add(mapOf("address" to address, "body" to (c.getString(1) ?: ""), "date" to c.getLong(2)))
                    }
                }
                main.post { result.success(out) }
            } catch (e: Exception) {
                main.post { result.error("inbox", e.message, null) }
            }
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        val o = object : ContentObserver(main) {
            override fun onChange(selfChange: Boolean) = sink.success(null)
        }
        try {
            activity.contentResolver.registerContentObserver(Telephony.Sms.CONTENT_URI, true, o)
            observer = o
        } catch (_: SecurityException) {
            // No SMS access yet: the app reads again when it's allowed.
        }
    }

    override fun onCancel(arguments: Any?) {
        observer?.let { activity.contentResolver.unregisterContentObserver(it) }
        observer = null
    }

    fun dispose() {
        onCancel(null)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        io.shutdown()
    }

    companion object {
        private const val REQUEST_CODE = 4821

        /** The message a tapped notification was about, until the app takes it. */
        var launch: Map<String, Any>? = null
    }
}
