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
    
    func append(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let lines = message.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty {
                let entry = LogEntry(message: line, isError: isError)
                self.entries.append(entry)
            }
            
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }
    
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
        }
    }
}
