package com.upi.yptk

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.upi.yptk/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannels()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }

                    // Cek izin instalasi aplikasi tidak dikenal di Android 8.0+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            try {
                                val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(settingsIntent)
                                result.success("REQUEST_PERMISSION")
                                return@setMethodCallHandler
                            } catch (e: Exception) {
                                // Fallback jika intent spesifik ditolak perangkat tertentu
                            }
                        }
                    }

                    try {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            val contentUri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "$packageName.fileprovider",
                                file
                            )
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success("SUCCESS")
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "playTestSound" -> {
                    try {
                        val soundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${packageName}/raw/siakad_notif")
                        val ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
                        ringtone?.play()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SOUND_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val soundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${packageName}/raw/siakad_notif")
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            // Channel 1: siakad_notif_channel (digunakan oleh payload backend OneSignal)
            val channel1 = NotificationChannel(
                "siakad_notif_channel",
                "Pengingat Kuliah SIAKAD",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi pengingat jadwal kuliah dan perkuliahan dimulai dengan suara khas SIAKAD"
                setSound(soundUri, audioAttributes)
                enableLights(true)
                lightColor = Color.YELLOW
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel1)

            // Channel 2: siakad_notif (fallback OneSignal jika ID channel disamakan dengan nama suara)
            val channel2 = NotificationChannel(
                "siakad_notif",
                "Notifikasi SIAKAD",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi SIAKAD dengan suara khusus"
                setSound(soundUri, audioAttributes)
                enableLights(true)
                lightColor = Color.YELLOW
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel2)

            // Channel 3: fcm_fallback_notification_channel (fallback bawaan OneSignal)
            val channel3 = NotificationChannel(
                "fcm_fallback_notification_channel",
                "Notifikasi Umum SIAKAD",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi umum SIAKAD UPI YPTK"
                setSound(soundUri, audioAttributes)
                enableLights(true)
                lightColor = Color.YELLOW
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel3)
        }
    }
}
