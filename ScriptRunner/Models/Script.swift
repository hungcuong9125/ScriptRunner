import Foundation

struct Script: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var isAutoStart: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String = "",
        isAutoStart: Bool = false
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.isAutoStart = isAutoStart
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var effectiveWorkingDirectory: String {
        if workingDirectory.isEmpty {
            return NSHomeDirectory().replacingOccurrences(
                of: "/Library/Containers/com.scriptrunner.app/Data",
                with: ""
            )
        }
        return (workingDirectory as NSString).expandingTildeInPath
    }
}

enum ScriptStatus: Equatable {
    case stopped
    case running
    case crashed(exitCode: Int32)
    
    var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .running: return "Running"
        case .crashed(let code): return "Crashed (\(code))"
        }
    }
    
    var icon: String {
        switch self {
        case .stopped: return "circle.fill"
        case .running: return "circle.fill"
        case .crashed: return "exclamationmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .stopped: return "gray"
        case .running: return "green"
        case .crashed: return "red"
        }
    }
}
