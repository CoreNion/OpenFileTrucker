package dev.cnion.trucker;

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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
            } else if (call.method == "openFileManager")
            {
                // PATHを送っているが、デフォルトアプリへの受け渡しは厳しそうなので保留中
                // val path = call.argument<String>("path")

                val intent = Intent(Intent.ACTION_VIEW)
                intent.setType("resource/folder")
                startActivity(intent);
            } else {
                result.notImplemented()
            }
        }
    }
}
