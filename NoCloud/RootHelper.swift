//
//  RootHelper.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/30.
//

import Cocoa
import Photos

class RootHelper {
    
    unowned var window: NSWindow
    
    var syncHelper: SyncHelper?
    
    var selectFolderUrl: URL? {
        didSet {
            updateSyncBtnState()
            
            guard let url = selectFolderUrl else {
                mainView.folderBtn.title = NSLocalizedString("Pick folder to save images", comment: "")
                return
            }
            mainView.folderBtn.title = "\(NSLocalizedString("Sync To", comment: "")):\(url.path)"
            
            // Cache folder path
            let std = UserDefaults.standard
            if let exist = std.object(forKey: "CACHED_FOLDER_PATH") as? String, exist == url.path {
                return
            }
            std.setValue(url.path, forKey: "CACHED_FOLDER_PATH")
            std.synchronize()
        }
    }
    
    private func updateSyncBtnState() {
        mainView.syncBtn.isEnabled = selectFolderUrl != nil
        mainView.trashBtn.isEnabled = selectFolderUrl != nil
        
        mainView.folderBtn.contentTintColor = selectFolderUrl != nil ? NSColor.labelColor : NSColor.secondaryLabelColor
    }
    
    
    var mainView: SyncMainView
    
    var progressView: SyncProgressView
    
    init(window: NSWindow) {
        self.window = window
        
        progressView = SyncProgressView.createFromNib()
        window.contentView?.addSubview(progressView)
        window.contentView?.edgeToSelf(view: progressView)
        progressView.isHidden = true
        
        mainView = SyncMainView.createFromNib()
        window.contentView?.addSubview(mainView)
        window.contentView?.edgeToSelf(view: mainView)
        
        setups()
    }
    
    func setups() {
        mainView.actionBlock = { [weak self] (action) in
            switch action {
            case .folder:
                self?.willPickFolder()
            case .sync:
                self?.willSync()
            case .trash:
                self?.willDeleteSyncAssets()
            }
        }
        
        progressView.actionBlock = { [weak self] (action) in
            switch action {
            case .cancel:
                self?.syncHelper?.stop()
                self?.hideMain(hidden: false)
            }
        }
        
        // use cache folder if it exist
        if let path = lastSyncFolder, path.hasPrefix("/Volumes/") == false {
            // U盘不选一下没有写入权限, 原因未知
            selectFolderUrl = URL(fileURLWithPath: path)
        }
    }
    
    private var lastSyncFolder: String? {
        let std = UserDefaults.standard
        var isDir:ObjCBool = false
        // use cache folder if it exist
        if let path = std.object(forKey: "CACHED_FOLDER_PATH") as? String,
           FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
           isDir.boolValue {
            return path
        }
        
        return nil
    }
    
    func hideMain(hidden: Bool) {
        progressView.isHidden = !hidden
        mainView.isHidden = hidden
    }
    
    private func willPickFolder() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        if let url = selectFolderUrl {
            openPanel.directoryURL = url
        } else if let path = lastSyncFolder {
            openPanel.directoryURL = URL(fileURLWithPath: path)
        }
        
        openPanel.begin { [weak self] (response) in
            if response == .OK {
                self?.selectFolderUrl = openPanel.url
                self?.updateInfo("")
            }
        }
    }
    
    private func checkAvailable(next: @escaping ()->Void) -> Bool {
        guard nil != selectFolderUrl else {
            updateInfo(NSLocalizedString("Please pick folder to save images", comment: ""))
            return false
        }
        
        // 检测权限
        let status = PHPhotoLibrary.authorizationStatus()
        if status != .authorized {
            updateInfo(NSLocalizedString("No authority to read albums", comment: ""))
            requestPhotoKitAuth(next: next)
            return false
        }
        
        return true
    }
    
    private func willSync() {
        guard checkAvailable(next: {
            self.beginSync()
        }) else { return }
        
        updateInfo("")

        self.beginSync()
    }
    
    private func willDeleteSyncAssets() {
        guard checkAvailable(next: {
            self.didDeleteSyncAssets()
        }) else { return }
        
        updateInfo("")
        
        didDeleteSyncAssets()
    }
    
    private func didDeleteSyncAssets() {
        guard let url = selectFolderUrl else {
            updateInfo(NSLocalizedString("Please pick folder to save images", comment: ""))
            return
        }
        
        updateInfo("开始移除已同步..")
        if syncHelper == nil || syncHelper?.folderUrl != url {
            syncHelper = SyncHelper(folder: url)
        }
        
        DispatchQueue.main.async {
            self.syncHelper?.window = self.window
            self.syncHelper?.moveSyncedAssetsToTrash()
        }
    }
    
    private func requestPhotoKitAuth(next: @escaping ()->Void) {
        PHPhotoLibrary.requestAuthorization { [weak self] (status) in
            if status == .authorized {
                DispatchQueue.main.async {
                    self?.updateInfo("已授权")
                    next()
                }
                return
            }
            
            self?.updateInfo("请求权限结果:\(status)")
        }
    }
    
    private func beginSync() {
        guard let url = selectFolderUrl else {
            updateInfo(NSLocalizedString("Please pick folder to save images", comment: ""))
            return
        }
        
        updateInfo("开始同步..")
        syncHelper = SyncHelper(folder: url)
        syncHelper?.statesBlock = { [weak self] (state) in
            switch state {
            case .info(let message):
                self?.updateInfo("\(message)")
            case .error(let error):
                self?.updateInfo("\(error)")
            case .progress(let success, let failed, let total):
                self?.progressView.updateProgress(success: success, failed: failed, total: total)
            case .finish(let success, let failed, let total):
                let message = "总共:\(total) 成功:\(success) 失败:\(failed)"
                DispatchQueue.main.async {
                    self?.showFinish(title: "同步已完成", message: message, action: {
                        self?.hideMain(hidden: false)
                    })
                }
            }
        }
        syncHelper?.syncBlock = {[weak self] (path, status) in
            switch status {
            case .success(_):
                self?.updateInfo("下载成功:\(path)")
            case .error(let error):
                self?.updateInfo("下载失败:\(path) err:\(error)")
            case .progress(let progress):
                self?.updateInfo("下载中:\(path) \(String(format: "%.0f", progress * 100))%")
            }
        }
        hideMain(hidden: true)
        DispatchQueue.main.async {
            self.syncHelper?.begin()
        }
    }
    
    @objc private func updateInfo(_ info: String) {
        #if DEBUG
        print(info)
        #endif
    }
    
    private func showFinish(title: String, message: String, action: (()->Void)?) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: NSLocalizedString("Confirm", comment: ""))
        alert.beginSheetModal(for: window) { (result) in
            if result == .alertFirstButtonReturn {
                action?()
            }
        }
    }
}

extension NSView {
    
    func edgeToSelf(view: NSView) {
        if view.superview != self {
            return
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }
}
