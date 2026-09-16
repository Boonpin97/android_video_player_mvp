package com.example.android_video_player_mvp

import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val mediaExecutor = Executors.newSingleThreadExecutor()

    private val subtitleFolders by lazy { SubtitleFolders(this, mediaExecutor) }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!subtitleFolders.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "player/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "pickSubtitleFolder" -> subtitleFolders.pick(call.argument<String>("initialUri"), result)
                "findSubtitle" -> subtitleFolders.find(call.argument<String>("uri"), call.argument<String>("name"), result)
                "scanVideos" -> mediaExecutor.execute {
                    try {
                        val rows = scanVideos()
                        runOnUiThread { result.success(rows) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("MEDIA_SCAN", error.message, null) }
                    }
                }
                "getBrightness" -> {
                    val override = window.attributes.screenBrightness
                    val system = Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128) / 255.0
                    result.success(if (override >= 0) override.toDouble() else system)
                }
                "setBrightness" -> {
                    val value = call.argument<Number>("value")?.toFloat() ?: -1f
                    window.attributes = window.attributes.apply {
                        screenBrightness = if (value < 0) -1f else value.coerceIn(0.02f, 1f)
                    }
                    result.success(null)
                }
                "getVolume" -> {
                    val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() /
                        audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1))
                }
                "setVolume" -> {
                    val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val value = call.argument<Number>("value")?.toDouble() ?: 0.5
                    val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    audio.setStreamVolume(AudioManager.STREAM_MUSIC, (value.coerceIn(0.0, 1.0) * max).roundToInt(), 0)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scanVideos(): List<Map<String, Any?>> {
        val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        val columns = mutableListOf(
            MediaStore.Video.Media._ID, MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DURATION, MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT, MediaStore.Video.Media.DATE_MODIFIED
        )
        if (modern) {
            columns.add(MediaStore.Video.Media.RELATIVE_PATH)
            columns.add(MediaStore.Video.Media.VOLUME_NAME)
        } else {
            columns.add(MediaStore.Video.Media.DATA)
        }
        val result = mutableListOf<Map<String, Any?>>()
        contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, columns.toTypedArray(),
            null, null, MediaStore.Video.Media.DISPLAY_NAME + " COLLATE NOCASE ASC")?.use { cursor ->
            fun string(column: String): String = cursor.getString(cursor.getColumnIndexOrThrow(column)) ?: ""
            fun number(column: String): Long = cursor.getLong(cursor.getColumnIndexOrThrow(column))
            while (cursor.moveToNext()) {
                val id = number(MediaStore.Video.Media._ID)
                val directory = if (modern) string(MediaStore.Video.Media.RELATIVE_PATH) else {
                    val path = string(MediaStore.Video.Media.DATA)
                    path.substringBeforeLast('/').removePrefix("/storage/emulated/0/").removePrefix("/sdcard/") + "/"
                }
                val volume = if (modern) string(MediaStore.Video.Media.VOLUME_NAME) else "external_primary"
                result.add(mapOf(
                    "id" to id.toString(), "title" to string(MediaStore.Video.Media.DISPLAY_NAME),
                    "directory" to directory, "volume" to volume,
                    "duration" to number(MediaStore.Video.Media.DURATION),
                    "width" to number(MediaStore.Video.Media.WIDTH),
                    "height" to number(MediaStore.Video.Media.HEIGHT),
                    "modified" to number(MediaStore.Video.Media.DATE_MODIFIED),
                    "uri" to ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id).toString()
                ))
            }
        }
        return result
    }

    override fun onDestroy() {
        subtitleFolders.dispose()
        mediaExecutor.shutdown()
        super.onDestroy()
    }
}
