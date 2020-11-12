//
//  PHAsset.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/29.
//

import Foundation
import Photos

// 进度回调
typealias FetchProgressBlock = (Double, Error?, UnsafeMutablePointer<ObjCBool>, [AnyHashable : Any]?) -> Void

extension PHAsset {
    
    enum Result {
        // 成功(id, 补充信息)
        case success(String, [String:Any]?)
        
        // 失败(id, 错误)
        case failure(String, Error)
    }
    
    class func completeInMainThread(result: PHAsset.Result, completion: ((PHAsset.Result) -> Void)? = nil) {
        guard let completion = completion else { return }
        
        if Thread.isMainThread {
            completion(result)
        } else {
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
