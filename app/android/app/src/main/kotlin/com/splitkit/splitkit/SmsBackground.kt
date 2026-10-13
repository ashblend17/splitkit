package com.splitkit.splitkit

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Runs the app's own SMS parser on one message without the UI: a Dart engine starts on
 * `smsBackgroundMain` (lib/main.dart), describes the message over `splitkit/sms_bg`, and is
 * destroyed. So the notification and the app read messages the same way. Gives up after 8 s.
 */
object SmsBackground {
    private const val TIMEOUT_MS = 8000L

    fun describe(context: Context, sms: Map<String, Any>, done: (Map<*, *>?) -> Unit) {
        val app = context.applicationContext
        val main = Handler(Looper.getMainLooper())
        val loader = FlutterInjector.instance().flutterLoader()
        main.post {
            loader.startInitialization(app)
            loader.ensureInitializationCompleteAsync(app, null, main) {
                val engine = FlutterEngine(app)
                var finished = false
                fun finish(result: Map<*, *>?) {
                    if (finished) return
                    finished = true
                    engine.destroy()
                    done(result)
                }
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "splitkit/sms_bg")
                channel.setMethodCallHandler { call, result ->
                    if (call.method != "ready") return@setMethodCallHandler result.notImplemented()
                    result.success(null)
                    channel.invokeMethod("describe", sms, object : MethodChannel.Result {
                        override fun success(r: Any?) = finish(r as? Map<*, *>)
                        override fun error(code: String, message: String?, details: Any?) = finish(null)
                        override fun notImplemented() = finish(null)
                    })
                }
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "smsBackgroundMain"),
                )
                main.postDelayed({ finish(null) }, TIMEOUT_MS)
            }
        }
    }
}
