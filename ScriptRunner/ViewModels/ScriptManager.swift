import Foundation
import Combine
import UserNotifications

class ScriptManager: ObservableObject {
    static let shared = ScriptManager()
    
    @Published private(set) var scripts: [Script] = []
    @Published private(set) var statuses: [UUID: ScriptStatus] = [:]
    @Published private(set) var logs: [UUID: LogStore] = [:]
    
    private var processes: [UUID: Process] = [:]
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
        guard statuses[script.id] != .running else { return }
        
        let logStore = logs[script.id] ?? LogStore()
        logs[script.id] = logStore
        
        let workingDir = script.effectiveWorkingDirectory
        
        logStore.append("[\(formattedDate())] Starting: \(script.command)")
        logStore.append("[\(formattedDate())] Working directory: \(workingDir)")
        
        guard FileManager.default.fileExists(atPath: workingDir) else {
            logStore.append("[\(formattedDate())] Error: Working directory does not exist", isError: true)
            statuses[script.id] = .crashed(exitCode: -1)
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", script.command]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        process.environment = ProcessInfo.processInfo.environment
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                logStore.append(output)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                logStore.append(output, isError: true)
            }
        }
        
        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                self.processes.removeValue(forKey: script.id)
                
                let exitCode = proc.terminationStatus
                if exitCode == 0 {
                    self.statuses[script.id] = .stopped
                    logStore.append("[\(self.formattedDate())] Process exited normally")
                } else {
                    self.statuses[script.id] = .crashed(exitCode: exitCode)
                    logStore.append("[\(self.formattedDate())] Process exited with code \(exitCode)", isError: true)
                    self.sendCrashNotification(script: script, exitCode: exitCode)
                }
            }
        }
        
        do {
            try process.run()
            processes[script.id] = process
            statuses[script.id] = .running
            logStore.append("[\(formattedDate())] Process started (PID: \(process.processIdentifier))")
        } catch {
            logStore.append("[\(formattedDate())] Failed to start: \(error.localizedDescription)", isError: true)
            statuses[script.id] = .crashed(exitCode: -1)
        }
    }
    
    func stopScript(_ script: Script) {
        guard let process = processes[script.id] else { return }
        
        process.terminate()
        processes.removeValue(forKey: script.id)
        statuses[script.id] = .stopped
        
        if let logStore = logs[script.id] {
            logStore.append("[\(formattedDate())] Process stopped by user")
        }
    }
    
    func restartScript(_ script: Script) {
        stopScript(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startScript(script)
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
