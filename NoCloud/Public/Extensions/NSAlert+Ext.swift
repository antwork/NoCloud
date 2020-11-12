//
//  NSAlert+Ext.swift
//  NoCloud
//
//  Created by qiang xu on 2020/11/2.
//

import Cocoa

extension NSAlert {
    
    static func showAlert(in window: NSWindow?,
                   title: String?,
                   message:String?,
                   cancelBtnTitle: String = NSLocalizedString("Cancel", comment: "")) {
        guard let window = window else { return }
        
        let alert = NSAlert()
        alert.messageText = title ?? ""
        alert.informativeText = message ?? ""
        alert.addButton(withTitle: cancelBtnTitle)
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
}
