package com.example.android_video_player_mvp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService

/** Reads only a user-selected document tree; no broad storage permission is needed. */
class SubtitleFolders(private val activity: Activity, private val executor: ExecutorService) {
    private var pendingPicker: MethodChannel.Result? = null
    private val requestCode = 7412

    @Suppress("DEPRECATION")
    fun pick(initialUri: String?, result: MethodChannel.Result) {
        if (pendingPicker != null) {
            result.error("PICKER_BUSY", "A folder picker is already open.", null)
            return
        }
        pendingPicker = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !initialUri.isNullOrEmpty()) {
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialUri))
                }
            }
            activity.startActivityForResult(intent, requestCode)
        } catch (error: Exception) {
            pendingPicker = null
            result.error("SUBTITLE_FOLDER", error.message, null)
        }
    }

    fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != requestCode) return false
        val result = pendingPicker ?: return true
        pendingPicker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        executor.execute {
            try {
                val resolver = activity.contentResolver
                resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
                var name = DocumentsContract.getTreeDocumentId(uri)
                resolver.query(documentUri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) name = it.getString(0) ?: name
                }
                activity.runOnUiThread { result.success(mapOf("uri" to uri.toString(), "name" to name)) }
            } catch (error: Exception) {
                activity.runOnUiThread { result.error("SUBTITLE_FOLDER", error.message, null) }
            }
        }
        return true
    }

    fun find(tree: String?, name: String?, result: MethodChannel.Result) {
        if (tree.isNullOrEmpty() || name.isNullOrEmpty() || !name.endsWith(".srt", ignoreCase = true)) {
            result.error("SUBTITLE_ARGUMENT", "A folder and SRT filename are required.", null)
            return
        }
        executor.execute {
            try {
                val treeUri = Uri.parse(tree)
                val children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, DocumentsContract.getTreeDocumentId(treeUri))
                val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE)
                var match: String? = null
                activity.contentResolver.query(children, columns, null, null, null)?.use { cursor ->
                    while (cursor.moveToNext()) {
                        if (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                        val candidate = cursor.getString(1) ?: continue
                        if (candidate == name) {
                            match = cursor.getString(0)
                            break
                        }
                        if (match == null && candidate.equals(name, ignoreCase = true)) match = cursor.getString(0)
                    }
                } ?: throw IllegalStateException("The subtitle folder cannot be read.")
                val path = match?.let { id ->
                    val uri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
                    val directory = File(activity.cacheDir, "matched_subtitles").apply { mkdirs() }
                    // Refresh on every open so edits to an SRT are picked up immediately.
                    val target = File(directory, "${uri.toString().hashCode().toUInt().toString(16)}.srt")
                    val input = activity.contentResolver.openInputStream(uri)
                        ?: throw IllegalStateException("The subtitle file cannot be read.")
                    input.use { source -> target.outputStream().use { output -> source.copyTo(output) } }
                    target.absolutePath
                }
                activity.runOnUiThread { result.success(path) }
            } catch (error: Exception) {
                activity.runOnUiThread { result.error("SUBTITLE_READ", error.message, null) }
            }
        }
    }

    fun dispose() {
        pendingPicker?.success(null)
        pendingPicker = null
    }
}
