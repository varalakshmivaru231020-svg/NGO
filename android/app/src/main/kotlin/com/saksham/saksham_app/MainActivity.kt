package com.saksham.saksham_app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL         = "saksham/image_picker"
    private val SAVER_CHANNEL   = "saksham/file_saver"
    private val CAMERA_REQUEST  = 1001
    private val GALLERY_REQUEST = 1002
    private val FILE_REQUEST    = 1003

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFromCamera"  -> { pendingResult = result; openCamera() }
                    "pickFromGallery" -> { pendingResult = result; openGallery() }
                    "pickFile"        -> { pendingResult = result; openFilePicker() }
                    else              -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAVER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveFile" -> {
                        val filename = call.argument<String>("filename") ?: "download"
                        val content  = call.argument<String>("content")  ?: ""
                        val mimeType = call.argument<String>("mimeType") ?: "text/plain"
                        result.success(saveFileToDownloads(filename, content, mimeType))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveFileToDownloads(filename: String, content: String, mimeType: String): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: return null
                contentResolver.openOutputStream(uri)?.use { it.write(content.toByteArray()) }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                filename
            } else {
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                dir.mkdirs()
                val file = File(dir, filename)
                file.writeText(content)
                file.absolutePath
            }
        } catch (e: Exception) { null }
    }

    private fun openCamera() {
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        startActivityForResult(intent, CAMERA_REQUEST)
    }

    private fun openGallery() {
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
        intent.type = "image/*"
        startActivityForResult(intent, GALLERY_REQUEST)
    }

    private fun openFilePicker() {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.type = "*/*"
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        startActivityForResult(Intent.createChooser(intent, "Select File"), FILE_REQUEST)
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (resultCode != Activity.RESULT_OK) {
            pendingResult?.success(null)
            pendingResult = null
            return
        }

        when (requestCode) {
            CAMERA_REQUEST -> {
                @Suppress("UNCHECKED_CAST")
                val bitmap = data?.extras?.get("data") as? Bitmap
                if (bitmap != null) {
                    pendingResult?.success(saveBitmapToCache(bitmap))
                } else {
                    pendingResult?.success(null)
                }
            }
            GALLERY_REQUEST -> {
                val uri = data?.data
                if (uri != null) {
                    pendingResult?.success(copyUriToCache(uri))
                } else {
                    pendingResult?.success(null)
                }
            }
            FILE_REQUEST -> {
                val uri = data?.data
                if (uri != null) {
                    pendingResult?.success(copyFileToCache(uri))
                } else {
                    pendingResult?.success(null)
                }
            }
        }
        pendingResult = null
    }

    private fun saveBitmapToCache(bitmap: Bitmap): String? = try {
        val file = File(cacheDir, "cam_${System.currentTimeMillis()}.jpg")
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        file.absolutePath
    } catch (e: Exception) { null }

    private fun copyUriToCache(uri: android.net.Uri): String? = try {
        val stream = contentResolver.openInputStream(uri) ?: return null
        val file   = File(cacheDir, "pick_${System.currentTimeMillis()}.jpg")
        stream.use { it.copyTo(file.outputStream()) }
        file.absolutePath
    } catch (e: Exception) { null }

    private fun copyFileToCache(uri: android.net.Uri): ArrayList<String>? = try {
        val name = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) cursor.getString(idx) else "file_${System.currentTimeMillis()}"
            } else "file_${System.currentTimeMillis()}"
        } ?: "file_${System.currentTimeMillis()}"

        val ext  = name.substringAfterLast('.', "bin")
        val file = File(cacheDir, "doc_${System.currentTimeMillis()}.$ext")
        contentResolver.openInputStream(uri)?.use { it.copyTo(file.outputStream()) }
        arrayListOf(file.absolutePath, name)
    } catch (e: Exception) { null }
}
