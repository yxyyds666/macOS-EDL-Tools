import SwiftUI

@main
struct EDLToolApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var updateService = UpdateService.shared
    @StateObject private var announcementService = AnnouncementService.shared
    
    @State private var showUpdateSheet = false
    @State private var showAnnouncementSheet = false
    @State private var showUpdateBanner = false
    @State private var hasCheckedOnLaunch = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                    .frame(minWidth: 900, minHeight: 600)
                    .onAppear {
                        checkOnLaunch()
                    }
                
                // 更新提示条
                if showUpdateBanner, let updateInfo = updateService.updateInfo {
                    VStack {
                        UpdateBanner(
                            updateInfo: updateInfo,
                            onTap: { showUpdateSheet = true },
                            onDismiss: { showUpdateBanner = false }
                        )
                        .padding()
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showUpdateSheet) {
                if let updateInfo = updateService.updateInfo {
                    UpdateView(
                        updateInfo: updateInfo,
                        onDownload: {
                            updateService.openDownloadPage()
                            showUpdateSheet = false
                        },
                        onDismiss: {
                            showUpdateSheet = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showAnnouncementSheet) {
                if let announcement = announcementService.currentAnnouncement {
                    AnnouncementView(
                        announcement: announcement,
                        onClose: {
                            announcementService.markAsRead()
                            showAnnouncementSheet = false
                        }
                    )
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu("帮助") {
                Button("检查更新") {
                    Task {
                        _ = try? await updateService.checkForUpdates()
                        if updateService.updateInfo?.isNewVersionAvailable == true {
                            showUpdateSheet = true
                        } else {
                            // 显示已是最新版本的提示
                            appState.addLog("已是最新版本", level: .success)
                        }
                    }
                }
                .keyboardShortcut("U", modifiers: .command)
                
                Divider()
                
                Button("查看公告") {
                    showAnnouncementSheet = true
                }
                .keyboardShortcut("A", modifiers: .command)
                
                Divider()
                
                Button("GitHub 仓库") {
                    if let url = URL(string: "https://github.com/yxyyds666/macOS-EDL-Tools") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("报告问题") {
                    if let url = URL(string: "https://github.com/yxyyds666/macOS-EDL-Tools/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    private func checkOnLaunch() {
        guard !hasCheckedOnLaunch else { return }
        hasCheckedOnLaunch = true
        
        Task {
            // 先检查公告
            await announcementService.fetchAnnouncement()
            
            // 延迟显示公告弹窗
            if announcementService.hasUnreadAnnouncement {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showAnnouncementSheet = true
                }
            }
            
            // 然后检查更新（静默）
            await updateService.checkForUpdatesSilently()
            
            // 如果有新版本，显示提示条
            if updateService.updateInfo?.isNewVersionAvailable == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showUpdateBanner = true
                }
            }
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    static let shared = AppState()
    
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