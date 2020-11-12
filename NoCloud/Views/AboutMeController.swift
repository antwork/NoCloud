//
//  AboutMeController.swift
//  NoCloud
//
//  Created by qiang xu on 2020/11/2.
//

import Cocoa
import WebKit

class AboutMeController: NSWindowController {

    @IBOutlet weak var webView: WKWebView!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.title = NSLocalizedString("Abount NoCloud", comment: "")
        
        guard let url = Bundle.main.url(forResource: "about", withExtension: "html") else { return }
        
        webView.load(URLRequest(url: url))
    }
    
}
