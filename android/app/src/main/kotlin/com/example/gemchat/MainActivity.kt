package com.example.gemchat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.gemchat/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveImageToGallery") {
                val filePath = call.argument<String>("filePath")
                val fileName = call.argument<String>("fileName") ?: "image_${System.currentTimeMillis()}.jpg"
                
                if (filePath == null) {
                    result.error("INVALID_ARGUMENT", "文件路径不能为空", null)
                    return@setMethodCallHandler
                }
                
                try {
                    val saved = saveImageToGallery(filePath, fileName)
                    if (saved) {
                        result.success("图片已保存到相册")
                    } else {
                        result.error("SAVE_FAILED", "保存图片失败", null)
                    }
                } catch (e: Exception) {
                    result.error("EXCEPTION", "保存图片时发生异常: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    
    private fun saveImageToGallery(filePath: String, fileName: String): Boolean {
        val sourceFile = File(filePath)
        if (!sourceFile.exists()) {
            return false
        }
        
        try {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            
            val contentResolver = context.contentResolver
            val imageUri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues) ?: return false
            
            contentResolver.openOutputStream(imageUri)?.use { outputStream ->
                FileInputStream(sourceFile).use { inputStream ->
                    val buffer = ByteArray(1024)
                    var bytesRead: Int
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        outputStream.write(buffer, 0, bytesRead)
                    }
                }
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(imageUri, contentValues, null, null)
            }
            
            return true
        } catch (e: IOException) {
            e.printStackTrace()
            return false
        }
    }
}
