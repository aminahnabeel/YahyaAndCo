package com.example.yahya_and_co

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "yahya_and_co/files"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method != "savePdf") {
					result.notImplemented()
					return@setMethodCallHandler
				}

				val fileName = call.argument<String>("fileName")
				val bytes = call.argument<ByteArray>("bytes")
				if (fileName.isNullOrBlank() || bytes == null) {
					result.error("INVALID_ARGUMENT", "PDF file name or bytes are missing", null)
					return@setMethodCallHandler
				}

				try {
					if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
						val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
							?: throw IllegalStateException("Could not access app storage")
						val file = java.io.File(directory, fileName)
						file.writeBytes(bytes)
						result.success(file.absolutePath)
						return@setMethodCallHandler
					}

					val values = ContentValues().apply {
						put(MediaStore.Downloads.DISPLAY_NAME, fileName)
						put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
						put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
						put(MediaStore.Downloads.IS_PENDING, 1)
					}

					val uri = contentResolver.insert(
						MediaStore.Downloads.EXTERNAL_CONTENT_URI,
						values,
					) ?: throw IllegalStateException("Could not create Downloads entry")

					try {
						contentResolver.openOutputStream(uri)?.use { output ->
							output.write(bytes)
						} ?: throw IllegalStateException("Could not open Downloads entry")

						values.clear()
						values.put(MediaStore.Downloads.IS_PENDING, 0)
						contentResolver.update(uri, values, null, null)
						result.success(uri.toString())
					} catch (error: Exception) {
						contentResolver.delete(uri, null, null)
						throw error
					}
				} catch (error: Exception) {
					result.error("SAVE_FAILED", error.message, null)
				}
			}
	}
}
