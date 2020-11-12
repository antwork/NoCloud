//
//  FetchSlowMo.swift
//  NoCloud
//
//  Created by qiang xu on 2020/11/4.
//

import Foundation
import Photos

extension PHAsset {
    
    
    /// 获取慢动作视频
    /// - Parameters:
    ///   - folder: 目标文件夹
    ///   - progress: 进度回调
    ///   - completion: 结果回调
    /// - Throws: 出错
    func fetchSlowMo(folder: URL,
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
        
        PHImageManager.default().requestExportSession(forVideo: self, options: option, exportPreset: AVAssetExportPresetHEVCHighestQualityWithAlpha) { (session, infos) in
            
            session?.outputURL = url
            session?.outputFileType = .mov
            session?.shouldOptimizeForNetworkUse = false
            session?.exportAsynchronously {
                AVURLAsset.handle(id: id, session: session, attrs: fileAttrs, completion: completion)
            }
        }
    }
}
