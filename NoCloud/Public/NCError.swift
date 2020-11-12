//
//  NCError.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Foundation

enum NCError: Error {
    
    // 文件已存在
    case fileExist(String, URL)
    
    // 无效的cgImage
    case invalidCg
    
    // 无效的pngRep
    case invalidPngRep
    
    // 写数据失败
    case write(Error)
    
    // 导出失败
    case exportFail(Any)
    
    // 超时
    case timeout
    
    // 不支持
    case unsupportFmt
    
    // 创建文件夹失败
    case createFolder(Error)
    
}
