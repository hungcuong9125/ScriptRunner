import Foundation

/// Protocol for executing shell commands - allows future expansion to other executors
protocol CommandExecutor {
    func execute(
        command: String,
        workingDirectory: String,
        environment: [String: String]?,
        instanceId: UUID,
        outputHandler: @escaping (String, Bool) -> Void,
        terminationHandler: @escaping (Int32) -> Void
    ) throws -> ExecutorHandle
}

/// Handle to control a running process
protocol ExecutorHandle {
    var processIdentifier: Int32 { get }
    var isRunning: Bool { get }
    var instanceId: UUID { get }
    func terminate()
    func forceTerminate()
    func sendSignal(_ signal: Int32)
}

/// Shell executor that runs commands via zsh with proper environment setup
final class ShellExecutor: CommandExecutor {
    
    /// Standard system paths that should always be available
    private static let systemPaths = [
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin"
    ]
    
    /// User-specific paths to include
    private static var userPaths: [String] {
        let home = realHomeDirectory
        return [
            "\(home)/.local/bin",
            "\(home)/.bun/bin",
            "\(home)/.cargo/bin",
            "\(home)/.nvm/versions/node/*/bin",
            "/Library/Frameworks/Python.framework/Versions/Current/bin"
        ]
    }
    
    /// Get the real home directory (not sandboxed)
    static var realHomeDirectory: String {
        let home = NSHomeDirectory()
        if home.contains("/Library/Containers/") {
            return home.components(separatedBy: "/Library/Containers/").first ?? home
        }
        return home
    }
    
    /// Build a comprehensive PATH string
    static func buildPath(additionalPaths: [String]? = nil) -> String {
        var paths = Set<String>()
        
        // Add existing PATH components
        if let existingPath = ProcessInfo.processInfo.environment["PATH"] {
            existingPath.components(separatedBy: ":").forEach { paths.insert($0) }
        }
        
        // Add system paths
        systemPaths.forEach { paths.insert($0) }
        
        // Add user paths that exist
        let fm = FileManager.default
        for pattern in userPaths {
            if pattern.contains("*") {
                // Handle glob patterns (e.g., nvm paths)
                let basePath = (pattern as NSString).deletingLastPathComponent
                let baseBase = (basePath as NSString).deletingLastPathComponent
                if fm.fileExists(atPath: baseBase) {
                    if let contents = try? fm.contentsOfDirectory(atPath: baseBase) {
                        for item in contents {
                            let fullPath = (baseBase as NSString).appendingPathComponent(item)
                            let binPath = (fullPath as NSString).appendingPathComponent("bin")
                            if fm.fileExists(atPath: binPath) {
                                paths.insert(binPath)
                            }
                        }
                    }
                }
            } else if fm.fileExists(atPath: pattern) {
                paths.insert(pattern)
            }
        }
        
        // Add additional paths
        additionalPaths?.forEach { paths.insert($0) }
        
        // Sort for consistency and return
        return paths.sorted().joined(separator: ":")
    }
    
    /// Build environment dictionary with enhanced PATH
    static func buildEnvironment(additionalEnv: [String: String]? = nil) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        
        // Set HOME to real home directory
        env["HOME"] = realHomeDirectory
        
        // Build comprehensive PATH
        env["PATH"] = buildPath()
        
        // Ensure SHELL is set
        if env["SHELL"] == nil {
            env["SHELL"] = "/bin/zsh"
        }
        
        // Merge additional environment
        additionalEnv?.forEach { env[$0.key] = $0.value }
        
        return env
    }
    
    func execute(
        command: String,
        workingDirectory: String,
        environment: [String: String]?,
        instanceId: UUID = UUID(),
        outputHandler: @escaping (String, Bool) -> Void,
        terminationHandler: @escaping (Int32) -> Void
    ) throws -> ExecutorHandle {
        
        let process = Process()
        
        // Use zsh with login shell
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        // Create a script that:
        // 1. Sources shell profiles
        // 2. Sets up signal handling for graceful shutdown
        // 3. Executes the command
        let wrappedCommand = """
        # Source shell profiles for PATH
        [ -f ~/.zshenv ] && source ~/.zshenv 2>/dev/null
        [ -f ~/.zprofile ] && source ~/.zprofile 2>/dev/null
        [ -f ~/.zshrc ] && source ~/.zshrc 2>/dev/null
        
        # Handle termination signals gracefully
        cleanup() {
            # Send SIGTERM to all child processes in our process group
            pkill -TERM -P $$ 2>/dev/null
            exit 0
        }
        trap cleanup SIGTERM SIGINT SIGHUP
        
        # Execute the command
        \(command)
        """
        
        process.arguments = ["-c", wrappedCommand]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        
        // Build environment
        var env = Self.buildEnvironment(additionalEnv: environment)
        
        // Critical: Set TERM to enable proper terminal behavior
        env["TERM"] = "xterm-256color"
        
        // Disable job control messages
        env["BASH_SILENCE_DEPRECATION_WARNING"] = "1"
        
        process.environment = env
        
        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Also provide stdin in case command needs it
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        
        // Buffers to accumulate incomplete UTF-8 sequences across reads
        var pendingStdout = Data()
        var pendingStderr = Data()
        let stdoutLock = NSLock()
        let stderrLock = NSLock()

        // Handle stdout
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutLock.lock()
            pendingStdout.append(data)
            if let output = String(data: pendingStdout, encoding: .utf8) {
                pendingStdout = Data()
                stdoutLock.unlock()
                DispatchQueue.main.async {
                    outputHandler(output, false)
                }
            } else {
                stdoutLock.unlock()
            }
        }

        // Handle stderr
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrLock.lock()
            pendingStderr.append(data)
            if let output = String(data: pendingStderr, encoding: .utf8) {
                pendingStderr = Data()
                stderrLock.unlock()
                DispatchQueue.main.async {
                    outputHandler(output, true)
                }
            } else {
                stderrLock.unlock()
            }
        }
        
        // Handle termination
        process.terminationHandler = { proc in
            // Clean up handlers
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            // Flush remaining UTF-8 buffers
            stdoutLock.lock()
            let remainingStdout = pendingStdout
            pendingStdout = Data()
            stdoutLock.unlock()
            if !remainingStdout.isEmpty, let output = String(data: remainingStdout, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async { outputHandler(output, false) }
            }

            stderrLock.lock()
            let remainingStderr = pendingStderr
            pendingStderr = Data()
            stderrLock.unlock()
            if !remainingStderr.isEmpty, let output = String(data: remainingStderr, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async { outputHandler(output, true) }
            }

            // Close pipes
            try? inputPipe.fileHandleForWriting.close()

            DispatchQueue.main.async {
                let status = proc.terminationStatus
                // SIGTERM (15) is a normal graceful termination, treat as success
                if status == 15 || status == 0 {
                    terminationHandler(0)
                } else {
                    terminationHandler(status)
                }
            }
        }
        
        try process.run()
        
        return ProcessHandle(
            process: process,
            inputPipe: inputPipe,
            outputPipe: outputPipe,
            errorPipe: errorPipe,
            instanceId: instanceId
        )
    }
}

/// Handle wrapper for Process
final class ProcessHandle: ExecutorHandle {
    private let process: Process
    private let inputPipe: Pipe
    private let outputPipe: Pipe
    private let errorPipe: Pipe
    private var terminationWorkItem: DispatchWorkItem?

    let instanceId: UUID

    var processIdentifier: Int32 {
        process.processIdentifier
    }

    var isRunning: Bool {
        process.isRunning
    }

    init(process: Process, inputPipe: Pipe, outputPipe: Pipe, errorPipe: Pipe, instanceId: UUID = UUID()) {
        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        self.instanceId = instanceId
    }
    
    /// Send a specific signal to the process
    func sendSignal(_ signal: Int32) {
        guard process.isRunning else { return }
        kill(process.processIdentifier, signal)
    }
    
    /// Graceful termination: SIGTERM first, then SIGKILL after timeout
    func terminate() {
        guard process.isRunning else { return }
        
        // Cancel any pending force termination
        terminationWorkItem?.cancel()
        
        // Send SIGTERM for graceful shutdown
        sendSignal(SIGTERM)
        
        // Schedule force kill if still running after 3 seconds
        let workItem = DispatchWorkItem { [weak self] in
            self?.forceTerminate()
        }
        terminationWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: workItem)
    }
    
    /// Force terminate immediately with SIGKILL
    func forceTerminate() {
        guard process.isRunning else { return }
        
        // Cancel pending work
        terminationWorkItem?.cancel()
        terminationWorkItem = nil
        
        // First try to kill the process group (to kill child processes too)
        let pgid = getpgid(process.processIdentifier)
        if pgid > 0 {
            kill(-pgid, SIGKILL)
        }
        
        // Also kill the main process directly
        sendSignal(SIGKILL)
    }
    
    /// Send input to the process stdin
    func sendInput(_ input: String) {
        guard process.isRunning else { return }
        if let data = input.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
    }
    
    deinit {
        terminationWorkItem?.cancel()
    }
}
