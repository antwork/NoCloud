//
//  SyncProgressView.swift
//  NoCloud
//
//  Created by qiang xu on 2020/10/30.
//

import Cocoa

class SyncProgressView: NSView {
    
    enum Action {
        case cancel
    }
    
    @IBOutlet weak var label: NSTextField!
    
    @IBOutlet weak var secondaryLabel: NSTextField!
    
    @IBOutlet weak var progressView: NSProgressIndicator!
    
    @IBOutlet weak var cancelBtn: NSButton!
    
    var actionBlock: ((Action) ->Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        reset()
    }
    
    override var isHidden: Bool {
        didSet {
            if isHidden {
                progressView.stopAnimation(nil)
            } else {
                progressView.startAnimation(nil)
            }
        }
    }
    
    @IBAction func cancelBtnClicked(_ sender: Any) {
        reset()
        
        actionBlock?(.cancel)
    }
    
    private func reset() {
        label.stringValue = NSLocalizedString("Synchronizing, please be patient", comment: "")
        secondaryLabel.stringValue = ""
    }
    
    func updateProgress(success: Int, failed: Int, total: Int) {
        if success + failed >= total {
            secondaryLabel.stringValue = NSLocalizedString("Sync has finished!!", comment: "")
        } else if failed > 0 {
            secondaryLabel.stringValue = String(format: NSLocalizedString("Total: %ld Success: %ld Failure: %ld", comment: ""), total, success, failed)
        } else {
            secondaryLabel.stringValue = String(format: NSLocalizedString("Total: %ld Success: %ld", comment: ""), total, success)
        }
    }
}

extension SyncProgressView: NibLoadable {}
