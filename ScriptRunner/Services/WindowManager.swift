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
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = MainWindowView(initialTab: tab, initialAction: action)
            .environmentObject(scriptManager)
        
        let hostingController = NSHostingController(rootView: AnyView(contentView))
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "ScriptRunner"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 700, height: 450)
        
        mainWindowDelegate = MainWindowDelegate { [weak self] in
            self?.mainWindow = nil
            self?.mainWindowDelegate = nil
            self?.hideDockIcon()
        }
        window.delegate = mainWindowDelegate
        
        mainWindow = window
        
        showDockIcon()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
