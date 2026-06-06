import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureNotifications()
        showMainWindowOnLaunch()
        startAutoStartScripts()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ScriptManager.shared.stopAllScripts()
    }
    
    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }
    
    private func showMainWindowOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WindowManager.shared.openMainWindow(
                tab: .scripts,
                scriptManager: ScriptManager.shared
            )
        }
    }

    private func startAutoStartScripts() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ScriptManager.shared.startAutoStartScripts()
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
