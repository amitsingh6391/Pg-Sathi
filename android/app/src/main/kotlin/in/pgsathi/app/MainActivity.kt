package `in`.pgsathi.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ClipData
import android.content.ClipboardManager
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WHATSAPP_SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copyImageToClipboard" -> result.success(
                        copyImageToClipboard(call.argument<String>("filePath") ?: "")
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Copies the owner's UPI QR image at [filePath] to the clipboard so it can
     * be pasted into a resident's WhatsApp chat. Returns false when missing.
     */
    private fun copyImageToClipboard(filePath: String): Boolean {
        val file = File(filePath)
        if (!file.exists()) return false
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val clipboard = getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newUri(contentResolver, "UPI QR", uri))
        return true
    }

    /**
     * Creates a notification channel for Android 8.0 (API 26) and above.
     * This is required for notifications to appear on Android devices.
     * The channel ID "default" matches the channelId used in Cloud Functions.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "default"
            val channelName = "Default Notifications"
            val channelDescription = "Default notification channel for PG Sathi"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val WHATSAPP_SHARE_CHANNEL = "in.pgsathi.app/whatsapp_share"
    }
}
