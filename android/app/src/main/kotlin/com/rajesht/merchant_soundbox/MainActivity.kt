package com.rajesht.merchant_soundbox

import android.content.*
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var eventSink: EventChannel.EventSink? = null
    private var tts: TextToSpeech? = null
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != PaymentNotificationListener.ACTION_NOTIFICATION) return
            eventSink?.success(mapOf(
                "package" to intent.getStringExtra("package"),
                "title" to intent.getStringExtra("title"),
                "body" to intent.getStringExtra("body"),
                "observedAt" to intent.getLongExtra("observedAt", System.currentTimeMillis())
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tts = TextToSpeech(this, this)
        registerReceiver(receiver, IntentFilter(PaymentNotificationListener.ACTION_NOTIFICATION), RECEIVER_NOT_EXPORTED)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "soundbox/notifications").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
            override fun onCancel(arguments: Any?) { eventSink = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soundbox/control").setMethodCallHandler { call, result ->
            when (call.method) {
                "notificationAccess" -> result.success(Settings.Secure.getString(contentResolver, "enabled_notification_listeners")?.contains(packageName) == true)
                "openNotificationAccess" -> { startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")); result.success(null) }
                "lastConnectedAt" -> result.success(getSharedPreferences("soundbox_health", MODE_PRIVATE).getLong("last_connected_at", 0))
                "announce" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val language = call.argument<String>("language") ?: "en-IN"
                    tts?.language = Locale.forLanguageTag(language)
                    result.success(tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "soundbox") != TextToSpeech.ERROR)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onInit(status: Int) { if (status == TextToSpeech.SUCCESS) tts?.language = Locale("en", "IN") }
    override fun onDestroy() { unregisterReceiver(receiver); tts?.shutdown(); super.onDestroy() }
}
