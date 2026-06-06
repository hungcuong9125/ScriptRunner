import SwiftUI
import AppKit

class WindowManager {
    static let shared = WindowManager()
    
    private var mainWindow: NSWindow?
    private var mainWindowDelegate: MainWindowDelegate?
    
    private init() {}
    
    func openMainWindow(
        tab: MainTab = .scripts,
        action: MainWindowAction = .none,
        scriptManager: ScriptManager
    ) {
        if let existingWindow = mainWindow {
            NotificationCenter.default.post(
                name: .navigateToAction,
                object: nil,
                userInfo: ["tab": tab, "action": action]
            )
            centerWindow(existingWindow)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = MainWindowView(initialTab: tab, initialAction: action)
            .environmentObject(scriptManager)
        
        let hostingController = NSHostingController(rootView: AnyView(contentView))
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.white.cgColor
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "ScriptRunner"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 700, height: 450)
        window.backgroundColor = .white
        
        mainWindowDelegate = MainWindowDelegate { [weak self] in
            self?.mainWindow = nil
            self?.mainWindowDelegate = nil
            self?.hideDockIcon()
        }
        window.delegate = mainWindowDelegate
        
        mainWindow = window
        
        showDockIcon()
        
        // Show window first
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Defer centering to next run loop so SwiftUI can finish layout
        DispatchQueue.main.async { [weak self] in
            self?.centerWindow(window)
        }
    }


    
    private func centerWindow(_ window: NSWindow) {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            
            let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
            
            // Set frame without changing size, but moving to calculated center
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
    }



    
    func closeMainWindow() {
        mainWindow?.close()
    }
    
    private func showDockIcon() {
        NSApp.setActivationPolicy(.regular)
    }
    
    private func hideDockIcon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

class MainWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

extension Notification.Name {
    static let navigateToAction = Notification.Name("ScriptRunner.navigateToAction")
}
