//
//  FetchLiveData.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Foundation
import Photos

extension PHAsset {
    
    /// 获取LiveData并转化为mov
    /// - Parameters:
    ///   - folder: 目标文件夹
    ///   - progress: 进度回调
    ///   - completion: 结果回调
    /// - Throws: 出错
    func fetchLiveData(folder: URL,
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
        
        let option = PHLivePhotoRequestOptions()
        option.version = .current
        option.deliveryMode = .highQualityFormat
        option.isNetworkAccessAllowed = true
        option.progressHandler = { (theProgress, error, stop, infos) in
            progress?(theProgress, error, stop, infos)
        }
        let fileAttrs:[FileAttributeKey: Any] = self.fileAttrs
        
        PHImageManager.default().requestLivePhoto(for: self, targetSize: PHImageManagerMaximumSize, contentMode: PHImageContentMode.default, options: option, resultHandler: { (livePhoto, infos) in
            if let livePhoto = livePhoto {
                let assetResources = PHAssetResource.assetResources(for: livePhoto)
                if let videoResource: PHAssetResource = assetResources.first(where: { $0.type == .pairedVideo }) {
                    PHAssetResourceManager.default().writeData(for: videoResource, toFile: url, options: nil) { (error) in
                        if let error = error {
                            PHAsset.completeInMainThread(result: .failure(id, error), completion: completion)
                        } else {
                            try? FileManager.default.setAttributes(fileAttrs, ofItemAtPath: url.path)
                            PHAsset.completeInMainThread(result: .success(id, ["URL":url]), completion: completion)
                        }
                    }
                    return
                }
            }
            PHAsset.completeInMainThread(result: .failure(id, NCError.exportFail(infos as Any)), completion: completion)
        })
    }
}
