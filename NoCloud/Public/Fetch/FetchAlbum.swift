//
//  FetchAlbum.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Foundation
import Photos

extension PHAssetCollection {
    
    /// 获取相册(包括系统相册和用户自定义相册)
    static func fetchAlbums() -> [PHAssetCollection] {
        
        // 获取系统和用户的最近项目
        let smartAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
        let userAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumUserLibrary, options: nil)
        
        var albums:[PHAssetCollection] = []
        
        smartAlbum.enumerateObjects { (collection, _, _) in
            albums.append(collection)
        }
        
        userAlbum.enumerateObjects { (collection, _, _) in
            albums.append(collection)
        }
        
        return albums
    }
}
