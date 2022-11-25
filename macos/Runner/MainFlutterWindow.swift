import Cocoa
import FlutterMacOS
import AVFoundation

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    
    let permissionChannel = FlutterMethodChannel(name: "com.corenion.filetrucker/permission", binaryMessenger: flutterViewController.engine.binaryMessenger)
      permissionChannel.setMethodCallHandler({
          [weak self] (call:  FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          
          guard call.method == "requestCameraPermission" else {
            result(FlutterMethodNotImplemented)
            return
          }
          self?.requestCameraPermission(result: result)
      })
      
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
    
    /// カメラの権限を要求する関数
    private func requestCameraPermission(result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                result(true)
            
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        result(true)
                    } else {
                        result(false)
                    }
                }
            
            case .denied:
                result(false)

            case .restricted:
                result(false)
        @unknown default:
            result(nil)
        }
    }
}
