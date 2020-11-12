//
//  URL+Ext.swift
//  NoCloud
//
//  Created by qiang xu on 2020/11/2.
//

import Foundation

extension URL {
    
    // 获取文件大小
    var fileSize: UInt64? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            return attrs[.size] as? UInt64
        } catch {
            return nil
        }
    }
}
