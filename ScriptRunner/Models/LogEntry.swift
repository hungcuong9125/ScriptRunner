import Foundation

struct LogEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let message: String
    let isError: Bool

    init(message: String, isError: Bool = false) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.isError = isError
    }

    var formattedTimestamp: String {
        DateFormatter.scriptRunnerTime.string(from: timestamp)
    }
}

class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    var count: Int { entries.count }
    private let maxEntries = 1000
    private let logFilePath: String?
    private var fileHandle: FileHandle?

    init(logFilePath: String? = nil) {
        self.logFilePath = logFilePath
        if let path = logFilePath {
            setupLogFile(at: path)
        }
    }

    private func setupLogFile(at path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        fileHandle = FileHandle(forWritingAtPath: path)
        fileHandle?.seekToEndOfFile()
    }

    func append(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let lines = message.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty {
                let entry = LogEntry(message: line, isError: isError)
                self.entries.append(entry)

                // Write to log file
                if let fileHandle = self.fileHandle {
                    let timestamp = entry.formattedTimestamp
                    let logLine = "[\(timestamp)] \(line)\n"
                    if let data = logLine.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                }
            }

            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
            // Truncate log file
            self?.fileHandle?.seek(toFileOffset: 0)
            self?.fileHandle?.truncateFile(atOffset: 0)
        }
    }

    deinit {
        fileHandle?.closeFile()
    }
}
