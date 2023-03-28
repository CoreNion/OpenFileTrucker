package com.corenion.filetrucker;

import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "com.corenion.filetrucker/info";

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
        .setMethodCallHandler(
            (call, result) -> {
              if (call.method.equals("getUserDeviceName")) {
                String userDeviceName = Settings.Global.getString(getContentResolver(), Settings.Global.DEVICE_NAME);
                
                result.success(userDeviceName);
              } else {
                result.notImplemented();
              }
            });
  }
}