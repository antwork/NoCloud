//
//  FetchImage.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Foundation
import Photos

extension PHAsset {
    
    func fetchImage(folder: URL,
                    progress: FetchProgressBlock? = nil,
                    completion: ((PHAsset.Result) -> Void)? = nil) throws {
        let url = self.fileURL(in: folder)
        var isDir: ObjCBool = false
        let id = localIdentifier
        
        // 已存在
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
           isDir.boolValue == false {
            throw NCError.fileExist(localIdentifier, url)
        }
        
        let option = PHImageRequestOptions()
        option.deliveryMode = .highQualityFormat
        option.isNetworkAccessAllowed = true
        option.isSynchronous = true
        option.progressHandler = { (aProgress, error, stop, infos) in
            progress?(aProgress, error, stop, infos)
        }
        
        let fileAttrs:[FileAttributeKey: Any] = self.fileAttrs
        
        PHImageManager.default().requestImage(for: self, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: option) { (image, values) in

            do {
                try image?.writePNG(toURL: url)
                try FileManager.default.setAttributes(fileAttrs, ofItemAtPath: url.path)

                PHAsset.completeInMainThread(result: .success(id, ["URL":url]), completion: completion)
            } catch {
                PHAsset.completeInMainThread(result: .failure(id, error), completion: completion)
            }
        }
    }
}
