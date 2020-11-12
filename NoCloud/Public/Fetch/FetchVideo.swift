//
//  FetchVideo.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Foundation
import Photos

extension PHAsset {
    
    
    /// 获取视频
    /// - Parameters:
    ///   - folder: 目标文件夹
    ///   - progress: 进度回调
    ///   - completion: 结果回调
    /// - Throws: 出错
    func fetchVideo(folder: URL,
                    progress: FetchProgressBlock? = nil,
                    completion: ((PHAsset.Result) -> Void)? = nil) throws {
        let url = self.fileURL(in: folder, ext: "mov")
        var isDir: ObjCBool = false
        let id = localIdentifier
        
        // 已存在
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
           isDir.boolValue == false {
            throw NCError.fileExist(localIdentifier, url)
        }
        
        let option = PHVideoRequestOptions()
        option.version = .current
        option.deliveryMode = .highQualityFormat
        option.isNetworkAccessAllowed = true
        option.progressHandler = { (theProgress, error, stop, infos) in
            progress?(theProgress, error, stop, infos)
        }
        
        let fileAttrs:[FileAttributeKey: Any] = self.fileAttrs
        
        PHImageManager.default().requestAVAsset(forVideo: self, options: option) { (asset, _, _) in
            if let item = asset as? AVURLAsset {
                do {
                    try item.fetch(id: id, url: url, attrs: fileAttrs, completion: completion)
                } catch {
                    PHAsset.completeInMainThread(result: .failure(id, error), completion: completion)
                }
            } else {
                PHAsset.completeInMainThread(result: .failure(id, NCError.unsupportFmt), completion: completion)
            }
        }
    }
}

extension AVURLAsset {
    
    static var currentExportID: String?
    
    func fetch(id:String, url: URL, attrs:[FileAttributeKey:Any], completion: ((PHAsset.Result) -> Void)? = nil) throws {
        let avAsset = AVURLAsset(url: self.url)
        
        // todo: 检查兼容性
//        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)
        
        let session = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
        session?.outputURL = url
        session?.outputFileType = .mov
        session?.shouldOptimizeForNetworkUse = false
        
        // 超时机制
        AVURLAsset.currentExportID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { // 暂定2分钟
            if id == AVURLAsset.currentExportID {
                PHAsset.completeInMainThread(result: .failure(id, NCError.timeout), completion: completion)
            }
        }
        
        session?.exportAsynchronously(completionHandler: {
            AVURLAsset.handle(id: id, session: session, attrs: attrs, completion: completion)
        })
    }
    
    class func handle(id: String, session: AVAssetExportSession?, attrs:[FileAttributeKey:Any], completion: ((PHAsset.Result) -> Void)?) {
        guard let session = session else {
            return
        }
        
        let status = session.status
        AVURLAsset.currentExportID = nil
        if status == .completed, let url = session.outputURL {
            PHAsset.completeInMainThread(result: .success(id, ["URL": url]), completion: completion)
            try? FileManager.default.setAttributes(attrs, ofItemAtPath: url.path)
        } else {
            PHAsset.completeInMainThread(result: .failure(id, NCError.exportFail(status)), completion: completion)
        }
    }
}
