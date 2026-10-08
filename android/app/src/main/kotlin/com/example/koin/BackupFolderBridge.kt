package com.example.koin

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.ByteArrayInputStream
import java.util.zip.GZIPInputStream

/** Persisted SAF grants allow local/USB folder backups without storage permissions. */
class BackupFolderBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "koin/backup")
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private val resolver get() = activity.contentResolver
    private val namePattern = Regex("^koin_recovery_(\\d+)\\.koin$")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "chooseFolder" -> {
                    if (pending != null) {
                        result.error("busy", "A folder picker is already open", null)
                    } else {
                        pending = result
                        try {
                            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                                putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                            }, REQUEST_CODE)
                        } catch (error: Exception) {
                            pending = null
                            result.error("folder_unavailable", error.message, null)
                        }
                    }
                }
                "writeBackup" -> {
                    val uri = call.argument<String>("uri")
                    val name = call.argument<String>("name")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (uri == null || name == null || bytes == null || !namePattern.matches(name)) {
                        result.error("invalid_backup", "Invalid backup request", null)
                    } else {
                        worker.execute {
                            try {
                                writeBackup(Uri.parse(uri), name, bytes)
                                activity.runOnUiThread { result.success(null) }
                            } catch (error: Exception) {
                                activity.runOnUiThread { result.error("backup_failed", error.message, null) }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        try {
            val flags = (data?.flags ?: 0) and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            resolver.takePersistableUriPermission(tree, flags)
            val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            val label = resolver.query(root, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            } ?: "Selected folder"
            result.success(mapOf("uri" to tree.toString(), "label" to label))
        } catch (error: Exception) {
            result.error("folder_unavailable", error.message, null)
        }
        return true
    }

    private fun children(tree: Uri, parent: Uri): List<Pair<String, Uri>> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getDocumentId(parent))
        return resolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null)?.use { cursor ->
            buildList {
                while (cursor.moveToNext()) add(cursor.getString(0) to
                    DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(1)))
            }
        } ?: error("Could not read backup folder")
    }

    private fun writeBackup(tree: Uri, name: String, bytes: ByteArray) {
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val folder = children(tree, root).firstOrNull { it.first == "Koin backups" }?.second
            ?: DocumentsContract.createDocument(resolver, root, DocumentsContract.Document.MIME_TYPE_DIR, "Koin backups")
            ?: error("Could not create backup folder")
        var existing = children(tree, folder).firstOrNull { it.first == name }?.second
        if (existing != null) {
            val saved = resolver.openInputStream(existing)?.use { it.readBytes() }
            if (saved == null || !saved.contentEquals(bytes)) {
                val intact = try {
                    if (saved == null) false else {
                        GZIPInputStream(ByteArrayInputStream(saved)).use { it.readBytes() }
                        true
                    }
                } catch (_: Exception) { false }
                check(!intact) { "Backup name already exists" }
                // An interrupted write may leave an incomplete document behind.
                // Retry that document without touching the other recovery copies.
                check(DocumentsContract.deleteDocument(resolver, existing)) { "Could not replace incomplete backup" }
                existing = null
            }
        }
        if (existing == null) {
            val file = DocumentsContract.createDocument(resolver, folder, "application/octet-stream", name)
                ?: error("Could not create backup")
            try {
                val output = resolver.openOutputStream(file, "w") ?: error("Could not open backup")
                output.use { it.write(bytes); it.flush() }
                val saved = resolver.openInputStream(file)?.use { it.readBytes() }
                check(saved != null && saved.contentEquals(bytes)) { "Backup verification failed" }
            } catch (error: Exception) {
                try { DocumentsContract.deleteDocument(resolver, file) } catch (_: Exception) { }
                throw error
            }
        }
        // Keep only our verified-format files; unrelated files are never removed.
        children(tree, folder).filter { namePattern.matches(it.first) }
            .sortedByDescending { namePattern.matchEntire(it.first)!!.groupValues[1].toLong() }
            .drop(3).forEach {
                check(DocumentsContract.deleteDocument(resolver, it.second)) { "Could not remove an old backup" }
            }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.success(null)
        pending = null
        worker.shutdown()
    }

    companion object { const val REQUEST_CODE = 7614 }
}
