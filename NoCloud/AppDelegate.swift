//
//  AppDelegate.swift
//  ImageSync
//  关于PhotoKit使用: https://developer.apple.com/documentation/photokit/browsing_and_modifying_photo_albums
//  Created by qiang xu on 2020/10/28.
//

import Cocoa
import Photos

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    @IBOutlet weak var syncBtn: NSButton!
    
    @IBOutlet weak var targetFolderLabel: NSTextField!
    
    @IBOutlet var statesView: NSTextView!
    
    @IBOutlet weak var progressView: NSTextField!
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    var rootHelper: RootHelper?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        rootHelper = RootHelper(window: self.window)
    }
    
    @IBAction func showAboutMe(_ sender: Any) {
        guard let url = URL(string: "https://github.com/antwork/NoCloud") else { return }
        NSWorkspace.shared.open(url)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension PHAuthorizationStatus: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .notDetermined:
            return "User has not yet made a choice with regards to this application"
        case .restricted:
            return "This application is not authorized to access photo data."
        case .denied:
            return "User has explicitly denied this application access to photos data"
        case .authorized:
            return "User has authorized this application to access photos data"
        default:
            return "Unknown Status:\(self.rawValue)"
        }
    }
}

