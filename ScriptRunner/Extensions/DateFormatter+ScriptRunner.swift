import Foundation

extension DateFormatter {
    static let scriptRunnerTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
