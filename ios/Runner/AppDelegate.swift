import UIKit
import Photos
import UniformTypeIdentifiers

import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let mediaChannel = FlutterMethodChannel(name: "dev.cnion.filetrucker/mediastore",
                                                binaryMessenger: controller.binaryMessenger)
        
        mediaChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "registerMediaStore"  {
                Task {
                    /* 与えられた写真/動画ファイルを、フォトライブラリーのアルバムに保存する */
                    let kAlbumName = "FileTrucker"
                    
                    // 写真パスを取得
                    guard let path = (call.arguments as? Dictionary<String, Any>)?["path"] as? String else {
                        result(FlutterError(code: "NEED_PATH", message: nil, details: nil))
                        return;
                    }
                    
                    // 権限の確認
                    if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .denied  {
                        result(FlutterError(code: "NEED_PERMISSION", message: nil, details: nil))
                        return;
                    }
                    
                    // 既存のアルバムを検索する
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.predicate = NSPredicate(format: "title = %@", kAlbumName)
                    // 検索結果のコレクションを取得
                    var collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
                    
                    // コレクションの存在確認
                    if collections.firstObject == nil {
                        // アルバムがない場合は作成する
                        do {
                            // アルバムを作成、プレースホルダーを取得
                            var albumPlaceholder: PHObjectPlaceholder?
                            try await PHPhotoLibrary.shared().performChanges({
                                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: kAlbumName)
                                albumPlaceholder = createRequest.placeholderForCreatedAssetCollection
                            })
                            
                            // コレクションを作成したアルバムに置き換え
                            collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers:[albumPlaceholder!.localIdentifier], options: nil)
                        } catch {
                            result(FlutterError(code: "FAILED_CREATE_ALBUM", message: nil, details: nil))
                            return;
                        }
                    }
                    
                    // アルバム(コレクション)の変更リクエストを取得
                    var albumChangeRequest: PHAssetCollectionChangeRequest?
                    do {
                        try await PHPhotoLibrary.shared().performChanges({
                            albumChangeRequest = PHAssetCollectionChangeRequest(for: collections.firstObject!)
                        })
                    } catch {
                        result(FlutterError(code: "FAILED_GET_ALBUM_CHANGE_REQUEST", message: nil, details: nil))
                        return;
                    }
                    
                    // パスをURLに変換
                    let url = URL(fileURLWithPath: path)
                    
                    // 写真ファイルをアルバムに保存
                    do {
                        try await PHPhotoLibrary.shared().performChanges({
                            // 作成リクエストを要求しファイルををアルバムに追加
                            var createAssetRequest: PHAssetChangeRequest?
                            if (UTType(filenameExtension: url.pathExtension)!.conforms(to: .image)) {
                                createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                            } else if (UTType(filenameExtension: url.pathExtension)!.conforms(to: .movie)){
                                createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                            } else {
                                result(FlutterError(code: "FILE_IS_NOT_MEDIA_FILE", message: nil, details: nil))
                                return;
                            }
                            
                            albumChangeRequest?.addAssets([createAssetRequest!.placeholderForCreatedAsset!] as NSFastEnumeration)
                        })
                    } catch {
                        result(FlutterError(code: "FAILED_SAVE_ALBUM", message: nil, details: nil))
                        return;
                    }
                    
                    // 残ったファイルを削除
                    try? FileManager.default.removeItem(atPath: path)
                    
                    result(true)
                }
            } else {
                result(FlutterMethodNotImplemented)
                return
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
