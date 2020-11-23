//
//  SyncFolderHelper.swift
//  ImageSync
//
//  Created by qiang xu on 2020/10/28.
//

import Foundation
import Photos
import Cocoa

class SyncHelper: NSObject {
    
    struct SyncItem {
        var localIdentifier: String     // 本地唯一id
        var albumName: String?          // 相册名称, 用于确定文件夹
        var size: Double                // image=width*height video=duration
    }
    
    enum DownloadStatus {
        case progress(Double)   // precent
        case success(URL)       // Path
        case error(Error)       // error
    }
    
    enum Status {
        case info(String)
        case error(String)
        case progress(Int, Int, Int) // 成功数/失败数/总数
        case finish(Int, Int, Int)   // 已结束: 成功数/失败数/总数
    }
    
    // 本地会移除的最小文件大小: 默认15kb
    static let SMALLEST_SIZE_TO_REMOVE:UInt64 = 15360
    
    static let DELETE_ALERT_MSG = NSLocalizedString("Unfortunately 🤷‍♀️, there is no official Api to completely delete resources, only resources can be moved into \"recently deleted\", Complete deletion method: Unlock iPhone-Open \"Photos\"-\"Photo Album\"-\"Recently Deleted\"-\"Select\"-\"Delete All\".The files moved into \"recently deleted\" must meet the following conditions:\n1. The files corresponding to iCloud exist locally.\n2. The local file size>%dkb.\nAlthough the above prevention of accidental deletion has been done, it is still recommended that you confirm the correctness of the backup before completely deleting it.", comment: "")
    
    var isStop: Bool = false
    
    var statesBlock: ((Status) ->Void)?
    
    var folderUrl: URL
    
    lazy var imageManager:PHImageManager = PHImageManager()
    
    var allSyncItems:[SyncItem]?
    
    var syncBlock: ((String, SyncHelper.DownloadStatus) -> Void)?
    
    var nextIndex:Int = 0
    
    // 失败的数量
    var failCount: Int = 0
    
    var currentAsset:PHAsset?
    
    var currentIdentifier: String?
    
    weak var window: NSWindow?
    
    init(folder: URL) {
        self.folderUrl = folder

        super.init()
        
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func begin() {
        let albums = PHAssetCollection.fetchAlbums()
        
        var syncItems: [SyncItem] = []
        var syncVideoItems: [SyncItem] = []
        
        let option = PHFetchOptions()
        option.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        for album in albums {
            // 如果未存在创建文件夹
            if let name = album.localizedTitle {
                let subFolder = folderUrl.appendingPathComponent(name)
                var isDir:ObjCBool = false
                if FileManager.default.fileExists(atPath: subFolder.path, isDirectory: &isDir) == false ||
                    isDir.boolValue == false {
                    do {
                        try FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: true, attributes: nil)
                        statesBlock?(.info("创建文件夹:\(subFolder.path)"))
                    } catch {
                        statesBlock?(.error("创建文件夹失败:\(subFolder.path)"))
                        return
                    }
                }
            }
            
            let assets = PHAsset.fetchAssets(in: album, options: option)
            assets.enumerateObjects { (asset, _, _) in
                if asset.mediaType == .video {
                    syncVideoItems.append(SyncItem(localIdentifier: asset.localIdentifier, albumName: album.localizedTitle,size: asset.duration))
                } else {
                    syncItems.append(SyncItem(localIdentifier: asset.localIdentifier,
                                              albumName: album.localizedTitle,
                                              size: Double(asset.pixelWidth * asset.pixelHeight)))
                }
            }
            statesBlock?(.info("找到相册:\(album.localizedTitle ?? "")"))
        }
        // 优先下载小文件, 优先下载照片
        syncItems.sort(by: { $0.size < $1.size })
        syncVideoItems.sort(by: { $0.size < $1.size })
        
        // 视频下载导出慢, 放后面
        syncItems.append(contentsOf: syncVideoItems)
        
        if syncItems.count == 0 {
            statesBlock?(.error(NSLocalizedString("No photo found, please check whether the photo permission is enabled", comment: "")))
            return
        }
        self.allSyncItems = syncItems
        self.isStop = false
        DispatchQueue.global().async {
            self.syncIfNeed()
        }
    }
    
    // 暂时逻辑, 一次同步一张
    private func syncIfNeed() {
        if isStop {
            statesBlock?(.finish(nextIndex-1, failCount, self.allSyncItems?.count ?? 0))
            statesBlock?(.info("err: 已结束 isStop==true"))
            return
        }
        
        guard let allPhotos = self.allSyncItems, allPhotos.count > 0, nextIndex < allPhotos.count else {
            statesBlock?(.finish(nextIndex, failCount, self.allSyncItems?.count ?? 0))
            return
        }

        let syncItem = allPhotos[nextIndex]
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [syncItem.localIdentifier], options: nil).firstObject else {
            statesBlock?(.info("err: 找不到资源\(syncItem.localIdentifier)"))
            self.failCurrentAndSyncNextIfNeed()
            return
        }
        
        let url = asset.fileURL(in: folderUrl.safeAppendingPathComponent(name: syncItem.albumName))
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue == false {
            var continueProcess = true
            // photoLive的导出视频和图片
            if asset.mediaType == .image, asset.mediaSubtypes.contains(.photoLive) {
                let url = asset.fileURL(in: folderUrl.safeAppendingPathComponent(name: syncItem.albumName), ext: "png")
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) == false || isDir.boolValue == true {
                    continueProcess = false
                }
            }
            if continueProcess {
                nextIndex += 1
                updateTotalProgress()
                DispatchQueue.global().async {
                    self.syncIfNeed()
                }
                return
            }
        }
        
        updateTotalProgress()
        
        DispatchQueue.global().async {
            self.sync(asset: asset, folderName: syncItem.albumName)
        }
        nextIndex += 1

        self.currentAsset = asset
    }
    
    func failCurrentAndSyncNextIfNeed() {
        failCount += 1
        DispatchQueue.global().async {
            self.syncIfNeed()
        }
    }
    
    
    /// 将已同步的内容移入已删除
    func moveSyncedAssetsToTrash() {
        let albums = PHAssetCollection.fetchAlbums()
        
        var willRemoveItems: [PHAsset] = []
        
        let option = PHFetchOptions()
        option.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        for album in albums {
            let assets = PHAsset.fetchAssets(in: album, options: option)
            assets.enumerateObjects { (asset, _, stop) in
                let url = asset.fileURL(in: self.folderUrl.safeAppendingPathComponent(name: album.localizedTitle))
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                   isDir.boolValue == false,
                   (url.fileSize ?? 0) > SyncHelper.SMALLEST_SIZE_TO_REMOVE {   /* 太小文件可能是缩略图 */
                    willRemoveItems.append(asset)
                }
            }
        }
        if willRemoveItems.isEmpty {
            NSAlert.showAlert(in: window, title: nil, message: NSLocalizedString("There are no resources that can be deleted, please check if the backup is exist", comment: ""))
            return
        }
        
        willRemoveAssets(willRemoveItems)
    }
    
    private func willRemoveAssets(_ assets: [PHAsset]) {
        guard let window = self.window else { return }
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Warning", comment: "")
        alert.informativeText = String(format: SyncHelper.DELETE_ALERT_MSG, SyncHelper.SMALLEST_SIZE_TO_REMOVE / 1024)
        alert.addButton(withTitle: NSLocalizedString("Confirm", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: window) {[weak self] (result) in
            if result == .alertFirstButtonReturn {
                self?.didRemoveAssets(assets)
            }
        }
    }
    
    private func didRemoveAssets(_ assets: [PHAsset]) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        } completionHandler: { [weak self] (success, error) in
            guard let window = self?.window else { return }
            if success {
                NSAlert.showAlert(in: window, title: NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Deleting takes a certain amount of time, please check the album later to confirm whether the removal operation is successful!", comment: ""), cancelBtnTitle: NSLocalizedString("OK", comment: ""))
            } else {
                NSAlert.showAlert(in: window, title: NSLocalizedString("Failed", comment: ""), message: error?.localizedDescription, cancelBtnTitle: NSLocalizedString("OK", comment: ""))
            }
            print("\(success) error:\(String(describing: error))")
        }
    }
    
    private func updateTotalProgress() {
        if let count = allSyncItems?.count, nextIndex != NSNotFound,  nextIndex <= count, nextIndex > 0 {
            DispatchQueue.main.async {
                self.statesBlock?(.progress(self.nextIndex - self.failCount, self.failCount, count))
            }
        }
    }
    
    func stop() {
        isStop = true
    }
    
    private func handleProgress(_ progress:Double, path: String, error: Error?, stop:UnsafeMutablePointer<ObjCBool>, infos:[AnyHashable : Any]?) {
        if let error = error {
            syncBlock?(path, .error(error))
        } else {
            syncBlock?(path, .progress(progress))
        }
    }
    
    private func handleResult(_ result: PHAsset.Result) {
        switch result {
        case .success(let id, let infos):
            if let url = infos?["URL"] as? URL {
                syncBlock?(id, .success(url))
            }
            print("同步成功:\(id) \(String(describing: infos))")
        case .failure(let id, let error):
            syncBlock?(id, .error(error))
            print("同步失败:\(id) \(error)")
        }
        syncIfNeed()
    }
    
    private func fetchPNG(asset:PHAsset, ext: String? = nil, targetFolder: URL, complete: @escaping (Result<PHAsset.Result, Error>)->Void) {
        do {
            try asset.fetchImage(folder: targetFolder, ext: ext) { [weak self] (progress, error, stop, infos) in
                self?.handleProgress(progress, path: targetFolder.path, error: error, stop: stop, infos: infos)
            } completion: { (result) in
                complete(.success(result))
            }
        } catch {
            complete(.failure(error))
        }
    }
    
    private func fetchMov(asset: PHAsset, targetFolder: URL, complete: @escaping (Result<PHAsset.Result, Error>)->Void) {
        do {
            try asset.fetchLiveData(folder: targetFolder) { [weak self] (progress, error, stop, infos) in
                self?.handleProgress(progress, path: targetFolder.path, error: error, stop: stop, infos: infos)
            } completion: { (result) in
                complete(.success(result))
            }
        } catch {
            complete(.failure(error))
        }
    }
    
    private func sync(asset: PHAsset, folderName: String?) {
        let localIdentifier = asset.localIdentifier
        
        let targetFolder = folderUrl.safeAppendingPathComponent(name: folderName)
        statesBlock?(.info("同步:\(asset) 开始"))
        switch asset.mediaType {
        case .image:
            if asset.mediaSubtypes.contains(.photoLive) {
                // 实况图片,先获取图片, 然后尝试获取视频
                fetchPNG(asset: asset, ext: "png", targetFolder: targetFolder) { [weak self] (result) in
                    self?.fetchMov(asset: asset, targetFolder: targetFolder, complete: { (result) in
                        switch result {
                        case .success(let resultAsset):
                            self?.handleResult(resultAsset)
                        case .failure(_):
                            // TODO: 处理错误
                            self?.failCurrentAndSyncNextIfNeed()
                        }
                    })
                }
            } else {
                self.fetchPNG(asset: asset, targetFolder: targetFolder) { [weak self] (result) in
                    switch result {
                    case .success(let resultAsset):
                        self?.handleResult(resultAsset)
                        break
                    case .failure(_):
                        // TODO: 处理错误
                        self?.failCurrentAndSyncNextIfNeed()
                    }
                }
            }
        case .video:
            // 慢动作
            if asset.mediaSubtypes.contains(.photoLive) {
                do {
                    try asset.fetchSlowMo(folder: targetFolder) { [weak self] (progress, error, stop, infos) in
                        self?.handleProgress(progress, path: targetFolder.path, error: error, stop: stop, infos: infos)
                    } completion: { [weak self] (result) in
                        self?.handleResult(result)
                    }
                    // 导出
                    print("准备导出慢动作视频:\(localIdentifier) \(targetFolder)")
                } catch {
                    // TODO: 处理错误
                    print("导出慢动作视频失败:\(localIdentifier) \(error)")
                    failCurrentAndSyncNextIfNeed()
                }
                return
            }
            do {
                try asset.fetchVideo(folder: targetFolder) { [weak self] (progress, error, stop, infos) in
                    self?.handleProgress(progress, path: targetFolder.path, error: error, stop: stop, infos: infos)
                } completion: { [weak self] (result) in
                    self?.handleResult(result)
                }

                // 导出
                print("准备导出视频:\(localIdentifier) \(targetFolder)")
            } catch {
                // TODO: 处理错误
                print("导出视频失败:\(localIdentifier) \(error)")
                failCurrentAndSyncNextIfNeed()
            }
        default:
            print("found:其他类型\(asset)")
            self.failCurrentAndSyncNextIfNeed()
            break
        }
    }
}

// MARK: PHPhotoLibraryChangeObserver
extension SyncHelper: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        print("changed")
    }
}
