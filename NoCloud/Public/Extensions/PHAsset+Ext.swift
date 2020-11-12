//
//  StringExt.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Foundation
import Photos

extension PHAsset {
    
    /// 本地存储路径
    /// - Parameters:
    ///   - folder: 本地文件夹URL
    ///   - ext: 文件名扩展(不传值根据asset类型自动判断)
    /// - Returns: 存储路径
    func fileURL(in folder: URL, ext: String? = nil) -> URL {
        let useExt:String
        if let ext = ext {
            useExt = ext
        } else {
            useExt = isExportToVideo ? "mov" : "png"
        }
            
        let name = "\(localIdentifier.replacingOccurrences(of: "/", with: "_")).\(useExt)"
        return folder.appendingPathComponent(name)
    }
    
    var fileAttrs: [FileAttributeKey: Any] {
        var fileAttrs: [FileAttributeKey: Any] = [:]
        if let creationDate = self.creationDate {
            fileAttrs[.creationDate] = creationDate
        }
        return fileAttrs
    }
    
    // 是否导出为视频
    var isExportToVideo: Bool {
        if mediaType == .video {
            return true
        }
        
        if mediaType == .image && mediaSubtypes.contains(.photoLive) {
            return true
        }
        
        return false
    }
}

extension URL {
    
    func safeAppendingPathComponent(name: String? = nil) -> URL {
        if let name = name {
            return self.appendingPathComponent(name)
        } else {
            return self
        }
    }
}
