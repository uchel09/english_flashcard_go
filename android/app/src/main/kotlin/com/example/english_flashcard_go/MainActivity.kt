package com.example.english_flashcard_go

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.flashcard.english/file_intent"
    private var methodChannel: MethodChannel? = null
    private var pendingFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    val path = pendingFilePath
                    pendingFilePath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        // Check if activity was launched with a VIEW intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val data = intent.data

        if (Intent.ACTION_VIEW == action && data != null) {
            val filePath = copyUriToCache(data)
            if (filePath != null) {
                pendingFilePath = filePath
                methodChannel?.invokeMethod("onFileReceived", filePath)
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            var fileName = "imported.flashdeck"
            if (uri.scheme == "content") {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            val name = it.getString(nameIndex)
                            if (!name.isNullOrBlank()) {
                                fileName = name
                            }
                        }
                    }
                }
            } else if (uri.scheme == "file") {
                val lastPath = uri.lastPathSegment
                if (!lastPath.isNullOrBlank()) {
                    fileName = lastPath
                }
            }

            if (!fileName.endsWith(".flashdeck", ignoreCase = true)) {
                fileName = "$fileName.flashdeck"
            }

            val targetFile = File(cacheDir, fileName)
            contentResolver.openInputStream(uri)?.use { inputStream ->
                FileOutputStream(targetFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            targetFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}

