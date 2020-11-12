//
//  WindowManager.swift
//
//  Created by qxu on 2019/5/23.
//

import Cocoa

class WindowManager {
    
    static var shared = WindowManager()
    
    private var holdControllers = Set<NSWindowController>()
    
    deinit {
        removeNotifications()
    }
    
    init() {
        addNotifications()
    }
    
    var notiObserver:NSObjectProtocol?
    
    func addNotifications() {
        removeNotifications()
        
        notiObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            guard let aWindow = notification.object as? NSWindow, let founds = self?.holdControllers.filter({ $0.window == aWindow }) else { return }
            
            for found in founds {
                self?.holdControllers.remove(found)
            }
        }
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeOptionalObserver(&notiObserver)
    }
    
    func push(_ window:NSWindowController) {
        holdControllers.insert(window)
    }
    
    func pop(checkBlock: (NSWindowController) -> Bool) -> [NSWindowController]? {
        if holdControllers.isEmpty { return nil }

        let items:[NSWindowController] = holdControllers.filter(checkBlock)
        guard items.isEmpty == false else { return nil }

        for (_, item) in items.enumerated() {
            holdControllers.remove(item)
        }
        return items
    }
}

extension NotificationCenter {
    
    /// 支持移除(观察者 or Nil)
    ///
    /// - Parameter observer: 观察者
    func removeOptionalObserver(_ observer: inout NSObjectProtocol?) {
        if let observer = observer {
            self.removeObserver(observer)
        }
        
        observer = nil
    }
}
