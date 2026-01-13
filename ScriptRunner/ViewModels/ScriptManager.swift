import Foundation
import Combine
import UserNotifications

class ScriptManager: ObservableObject {
    static let shared = ScriptManager()
    
    @Published private(set) var scripts: [Script] = []
    @Published private(set) var statuses: [UUID: ScriptStatus] = [:]
    @Published private(set) var logs: [UUID: LogStore] = [:]
    
    private var handles: [UUID: ExecutorHandle] = [:]
    private let executor: CommandExecutor = ShellExecutor()
    private let storageKey = "ScriptRunner.scripts"
    
    var hasRunningScripts: Bool {
        statuses.values.contains { $0 == .running }
    }
    
    var runningCount: Int {
        statuses.values.filter { $0 == .running }.count
    }
    
    private init() {
        loadScripts()
    }
    
    func loadScripts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Script].self, from: data) else {
            return
        }
        scripts = decoded
        for script in scripts {
            statuses[script.id] = .stopped
            logs[script.id] = LogStore()
        }
    }
    
    func saveScripts() {
        if let encoded = try? JSONEncoder().encode(scripts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func addScript(_ script: Script) {
        scripts.append(script)
        statuses[script.id] = .stopped
        logs[script.id] = LogStore()
        saveScripts()
    }
    
    func updateScript(_ script: Script) {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            var updated = script
            updated.updatedAt = Date()
            scripts[index] = updated
            saveScripts()
        }
    }
    
    func deleteScript(_ script: Script) {
        stopScript(script)
        scripts.removeAll { $0.id == script.id }
        statuses.removeValue(forKey: script.id)
        logs.removeValue(forKey: script.id)
        saveScripts()
    }
    
    func startScript(_ script: Script) {
        // Check if already running or if there's a stale handle
        if let existingHandle = handles[script.id] {
            if existingHandle.isRunning {
                return
            } else {
                // Clean up stale handle
                handles.removeValue(forKey: script.id)
            }
        }
        
        let logStore = logs[script.id] ?? LogStore()
        logs[script.id] = logStore
        
        let workingDir = script.effectiveWorkingDirectory
        
        logStore.append("[\(formattedDate())] ══════════════════════════════════════")
        logStore.append("[\(formattedDate())] Starting: \(script.command)")
        logStore.append("[\(formattedDate())] Working directory: \(workingDir)")
        
        guard FileManager.default.fileExists(atPath: workingDir) else {
            logStore.append("[\(formattedDate())] Error: Working directory does not exist", isError: true)
            statuses[script.id] = .crashed(exitCode: -1)
            return
        }
        
        // Log environment info for debugging
        let path = ShellExecutor.buildPath()
        logStore.append("[\(formattedDate())] HOME: \(ShellExecutor.realHomeDirectory)")
        logStore.append("[\(formattedDate())] PATH components: \(path.components(separatedBy: ":").count)")
        
        do {
            let scriptId = script.id
            let handle = try executor.execute(
                command: script.command,
                workingDirectory: workingDir,
                environment: nil,
                outputHandler: { output, isError in
                    logStore.append(output, isError: isError)
                },

                terminationHandler: { [weak self] exitCode in
                    guard let self = self else { return }
                    
                    self.handles.removeValue(forKey: scriptId)
                    
                    if exitCode == 0 {
                        self.statuses[scriptId] = .stopped
                        logStore.append("[\(self.formattedDate())] Process exited normally")
                    } else {
                        self.statuses[scriptId] = .crashed(exitCode: exitCode)
                        logStore.append("[\(self.formattedDate())] Process exited with code \(exitCode)", isError: true)
                        if let script = self.scripts.first(where: { $0.id == scriptId }) {
                            self.sendCrashNotification(script: script, exitCode: exitCode)
                        }
                    }
                }
            )
            
            handles[script.id] = handle
            statuses[script.id] = .running
            logStore.append("[\(formattedDate())] Process started (PID: \(handle.processIdentifier))")
            
        } catch {
            logStore.append("[\(formattedDate())] Failed to start: \(error.localizedDescription)", isError: true)
            statuses[script.id] = .crashed(exitCode: -1)
        }
    }
    
    func stopScript(_ script: Script) {
        guard let handle = handles[script.id], handle.isRunning else {
            // Clean up if handle exists but not running
            handles.removeValue(forKey: script.id)
            statuses[script.id] = .stopped
            return
        }
        
        if let logStore = logs[script.id] {
            logStore.append("[\(formattedDate())] Stopping process (PID: \(handle.processIdentifier))...")
        }
        
        // Update status to indicate stopping
        handle.terminate()
        
        // Note: Don't immediately remove handle or update status
        // Let the termination handler do it when process actually exits
    }
    
    func restartScript(_ script: Script) {
        let scriptId = script.id
        stopScript(script)
        
        // Wait a bit longer for graceful shutdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if let script = self.scripts.first(where: { $0.id == scriptId }) {
                self.startScript(script)
            }
        }
    }
    
    /// Execute the custom kill command for a script
    func forceKillScript(_ script: Script) {
        guard script.hasKillCommand else { return }
        
        let logStore = logs[script.id] ?? LogStore()
        logs[script.id] = logStore
        
        logStore.append("[\(formattedDate())] ══════════════════════════════════════")
        logStore.append("[\(formattedDate())] Executing force kill command...")
        logStore.append("[\(formattedDate())] Command: \(script.killCommand)")
        
        // First, force terminate the handle if it exists
        if let handle = handles[script.id] {
            handle.forceTerminate()
            handles.removeValue(forKey: script.id)
        }
        
        // Execute the kill command
        let workingDir = script.effectiveWorkingDirectory
        
        do {
            let scriptId = script.id
            _ = try executor.execute(
                command: script.killCommand,
                workingDirectory: workingDir,
                environment: nil,
                outputHandler: { output, isError in
                    logStore.append(output, isError: isError)
                },

                terminationHandler: { [weak self] exitCode in
                    guard let self = self else { return }
                    
                    if exitCode == 0 {
                        logStore.append("[\(self.formattedDate())] Force kill completed successfully")
                    } else {
                        logStore.append("[\(self.formattedDate())] Force kill exited with code \(exitCode)", isError: true)
                    }
                    
                    // Update status to stopped after kill command
                    self.statuses[scriptId] = .stopped
                }
            )
            
            logStore.append("[\(formattedDate())] Force kill command started")
            statuses[script.id] = .stopped
            
        } catch {
            logStore.append("[\(formattedDate())] Failed to execute kill command: \(error.localizedDescription)", isError: true)
            statuses[script.id] = .stopped
        }
    }

    
    func startAllScripts() {
        for script in scripts {
            if statuses[script.id] != .running {
                startScript(script)
            }
        }
    }
    
    func stopAllScripts() {
        for script in scripts {
            stopScript(script)
        }
    }
    
    func startAutoStartScripts() {
        for script in scripts where script.isAutoStart {
            startScript(script)
        }
    }
    
    func clearLog(for script: Script) {
        logs[script.id]?.clear()
    }
    
    func exportConfiguration() -> Data? {
        try? JSONEncoder().encode(scripts)
    }
    
    func importConfiguration(from data: Data) throws {
        let imported = try JSONDecoder().decode([Script].self, from: data)
        
        for script in imported {
            if !scripts.contains(where: { $0.id == script.id }) {
                addScript(script)
            }
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    private func sendCrashNotification(script: Script, exitCode: Int32) {
        let content = UNMutableNotificationContent()
        content.title = "Script Crashed"
        content.body = "\(script.name) exited with code \(exitCode)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
