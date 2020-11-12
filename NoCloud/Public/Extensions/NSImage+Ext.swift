//
//  NSImage+Ext.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Cocoa

public extension NSImage {
    
    /// 存储图片
    /// - Parameter url: 存储地址
    /// - Throws: 报错
    func writePNG(toURL url: URL) throws {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NCError.invalidCg
        }
        
        let newRep = NSBitmapImageRep(cgImage: cgImage)
        newRep.size = size // if you want the same size
        guard let pngData = newRep.representation(using: .png, properties: [:]) else {
            throw NCError.invalidPngRep
        }
        do {
            try pngData.write(to: url)
        } catch {
            throw NCError.write(error)
        }
    }
}
