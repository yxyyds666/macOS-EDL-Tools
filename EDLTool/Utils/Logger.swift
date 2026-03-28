import Foundation

// MARK: - Logger Service
class Logger: ObservableObject {
    static let shared = Logger()
    
    @Published var entries: [LogEntry] = []
    private let maxEntries = 2000
    
    private var logFileURL: URL? {
        let appSupport = FileManager.default.applicationSupportDirectory
        return appSupport.appendingPathComponent("EDLTool/logs/\(getLogFileName())")
    }
    
    private func getLogFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "edltool_\(formatter.string(from: Date())).log"
    }
    
    // MARK: - Log Methods
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, file: file, function: function, line: line)
    }
    
    private func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        let entry = LogEntry(
            message: message,
            level: level
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entries.append(entry)
            
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
        
        // Also write to file
        writeToLogFile(entry: entry, file: file, function: function, line: line)
    }
    
    private func writeToLogFile(entry: LogEntry, file: String, function: String, line: Int) {
        guard let logURL = logFileURL else { return }
        
        // Ensure log directory exists
        let logDirectory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(entry.timestamp)] [\(entry.level.rawValue.uppercased())] [\(fileName):\(line) \(function)] \(entry.message)\n"
        
        guard let data = logMessage.data(using: .utf8) else { return }
        
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: logURL)
        }
    }
    
    // MARK: - Export
    func exportLogs() -> String {
        entries.map { entry in
            "[\(entry.timestamp)] [\(entry.level)] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    func clearLogs() {
        entries.removeAll()
    }
}

// MARK: - Log Level Extension
extension LogLevel {
    var rawValue: String {
        switch self {
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .success: return "SUCCESS"
        }
    }
}
