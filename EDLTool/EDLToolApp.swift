import SwiftUI

@main
struct EDLToolApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var connectedDevice: USBDevice?
    @Published var isMonitoring: Bool = false
    @Published var partitions: [Partition] = []
    @Published var logs: [LogEntry] = []
    @Published var currentOperation: FlashOperation?
    
    func addLog(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(message: message, level: level)
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > 1000 {
                self.logs.removeFirst(100)
            }
        }
    }
}

// MARK: - Log Entry
struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let level: LogLevel
    let timestamp = Date()
}

enum LogLevel {
    case info, warning, error, success
    
    var color: Color {
        switch self {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .success: return "checkmark.circle"
        }
    }
}
