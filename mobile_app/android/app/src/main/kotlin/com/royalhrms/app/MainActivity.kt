package com.royalhrms.app

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Training PowerPoint / Word files (HO-47): hand a temporary,
        // app-private copy to another app, read-only. Only files inside
        // cacheDir/profile_docs/ and only the two Office types are accepted.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "royalhrms/training_files")
            .setMethodCallHandler { call, result ->
                if (call.method != "openDocument") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val mime = call.argument<String>("mime")
                result.success(openDocument(path, mime))
            }
    }

    private fun openDocument(path: String?, mime: String?): String {
        val allowed = setOf(
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        )
        if (path == null || mime == null || mime !in allowed) return "error"
        return try {
            val root = File(cacheDir, "profile_docs").canonicalFile
            val file = File(path).canonicalFile
            if (file.parentFile != root || !file.isFile) return "error"
            val uri = FileProvider.getUriForFile(this, "$packageName.trainingfiles", file)
            val view = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, mime)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (view.resolveActivity(packageManager) == null) return "no_app"
            startActivity(Intent.createChooser(view, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            "opened"
        } catch (e: ActivityNotFoundException) {
            "no_app"
        } catch (e: Exception) {
            "error"
        }
    }
}
