package dev.cnion.trucker;

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import androidx.annotation.NonNull
import java.io.File

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.cnion.filetrucker/mediastore").setMethodCallHandler {
                call, result ->
            if (call.method == "registerMediaStore") {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("NEED_PATH", null, null)
                    return@setMethodCallHandler
                }

                val file = File(path)
                // MediaScannerにスキャンするよう要求する
                MediaScannerConnection.scanFile(context, arrayOf(file.toString()),
                    null, null)

                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
