package com.rajesht.merchant_soundbox

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class PaymentNotificationListener : NotificationListenerService() {
    companion object {
        const val ACTION_NOTIFICATION = "com.rajesht.merchant_soundbox.PAYMENT_NOTIFICATION"
        private val ALLOWED = setOf(
            "com.google.android.apps.nbu.paisa.user",
            "com.phonepe.app",
            "net.one97.paytm",
            "in.org.npci.upiapp"
        )
    }

    override fun onListenerConnected() {
        getSharedPreferences("soundbox_health", MODE_PRIVATE).edit()
            .putLong("last_connected_at", System.currentTimeMillis()).apply()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!ALLOWED.contains(sbn.packageName)) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString().orEmpty()
        val body = extras.getCharSequence("android.text")?.toString().orEmpty()
        if (title.isBlank() && body.isBlank()) return
        sendBroadcast(Intent(ACTION_NOTIFICATION).setPackage(packageName).apply {
            putExtra("package", sbn.packageName)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("observedAt", sbn.postTime)
        })
    }
}
