//
//  SyncMainView.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/30.
//

import Cocoa

class SyncMainView: NSView {
    
    enum Action {
        case sync
        case trash
        case folder
    }
        
    @IBOutlet var contentView: NSView!
    
    @IBOutlet weak var syncBtn: NSButton!
    
    @IBOutlet weak var trashBtn: NSButton!
    
    @IBOutlet weak var folderBtn: NSButton!
    
    var actionBlock: ((Action) -> Void)?
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        
        syncBtn.toolTip = NSLocalizedString("Sync images", comment: "")
        trashBtn.toolTip = NSLocalizedString("Remove synced images", comment: "")
    }
    
    @IBAction func folderBtnClicked(_ sender: Any) {
        actionBlock?(.folder)
    }
    
    @IBAction func syncClicked(_ sender: Any) {
        actionBlock?(.sync)
    }
    
    @IBAction func trashBtnClicked(_ sender: Any) {
        actionBlock?(.trash)
    }
    
}

extension SyncMainView: NibLoadable {}


