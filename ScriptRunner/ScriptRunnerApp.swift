import SwiftUI

@main
struct ScriptRunnerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var scriptManager = ScriptManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(scriptManager)
        } label: {
            Image(systemName: scriptManager.hasRunningScripts ? "terminal.fill" : "terminal")
        }
        .menuBarExtraStyle(.window)
    }
}
