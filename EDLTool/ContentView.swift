import SwiftUI

// MARK: - 引导选择类型
enum BootloaderSelection: String, CaseIterable, Identifiable {
    case custom = "自定义引导"
    case onePlus = "一加免授权"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .custom: return "doc.badge.plus"
        case .onePlus: return "cpu.fill"
        }
    }
    
    var description: String {
        switch self {
        case .custom: return "选择自定义 Firehose 引导文件 (.elf/.mbn)"
        case .onePlus: return "选择处理器型号，自动加载对应引导"
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var deviceVM = DeviceViewModel()
    @StateObject private var flashVM = FlashViewModel()
    
    @State private var showPartitionSheet = false
    @State private var showXMLSheet = false
    @State private var showOnePlusMaintenanceAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    
    // 引导选择
    @State private var bootloaderSelection: BootloaderSelection = .custom
    @State private var bootloaderPath: URL?
    @State private var isSendingBootloader = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧主内容
            VStack(spacing: 0) {
                // 顶部设备状态栏
                DeviceStatusBar(deviceVM: deviceVM)
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
                
                // 主内容区
                ScrollView {
                    VStack(spacing: 16) {
                        // 引导选择卡片
                        BootloaderSelectionCard(
                            bootloaderSelection: $bootloaderSelection,
                            bootloaderPath: $bootloaderPath,
                            isSendingBootloader: $isSendingBootloader,
                            hasDevice: deviceVM.connectedDevice != nil,
                            onSendBootloader: sendBootloader,
                            onOnePlusSelected: { showOnePlusMaintenanceAlert = true }
                        )
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // 功能卡片
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            FunctionCard(
                                icon: "externaldrive.fill",
                                title: "分区管理",
                                description: "读取、写入、擦除分区",
                                color: .blue,
                                disabled: deviceVM.connectedDevice == nil
                            ) {
                                showPartitionSheet = true
                            }
                            
                            FunctionCard(
                                icon: "doc.text.fill",
                                title: "XML 刷机",
                                description: "使用 XML 文件批量刷写",
                                color: .orange,
                                disabled: deviceVM.connectedDevice == nil
                            ) {
                                showXMLSheet = true
                            }
                        }
                        .padding(.horizontal)
                        
                        // 操作状态
                        if flashVM.isOperating {
                            OperationStatusView(
                                status: flashVM.operationStatus,
                                progress: flashVM.operationProgress
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
            }
            
            Divider()
            
            // 右侧日志面板
            LogPanelView()
                .frame(width: 320)
        }
        .navigationTitle("EDL Tool")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    deviceVM.startMonitoring()
                } label: {
                    Label("刷新设备", systemImage: "arrow.clockwise")
                }
                .help("刷新设备连接")
            }
        }
        .onAppear {
            deviceVM.startMonitoring()
        }
        .onChange(of: deviceVM.connectedDevice) { newDevice in
            // 设备断开时重置发送状态
            if newDevice == nil && isSendingBootloader {
                isSendingBootloader = false
            }
        }
        .sheet(isPresented: $showPartitionSheet) {
            PartitionManagerSheet(flashVM: flashVM)
        }
        .sheet(isPresented: $showXMLSheet) {
            XMLFlashSheet(flashVM: flashVM)
        }
        .alert("功能维护中", isPresented: $showOnePlusMaintenanceAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("一加免授权功能正在维护中，请使用自定义引导文件。")
        }
        .alert("发送失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("发送成功", isPresented: $showSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("引导文件已成功发送到设备。")
        }
        .environmentObject(deviceVM)
        .environmentObject(flashVM)
    }
    
    private func sendBootloader() {
        guard let url = bootloaderPath else { return }
        
        // 检查是否有设备连接
        guard hasDevice else {
            errorMessage = "未检测到设备，请将设备进入 EDL 模式后重试"
            showErrorAlert = true
            return
        }
        
        // 检查文件扩展名
        let ext = url.pathExtension.lowercased()
        if !["elf", "mbn", "melf", "bin"].contains(ext) {
            errorMessage = "请选择正确的引导文件 (.elf, .mbn, .melf, .bin)\n\n当前文件: \(url.lastPathComponent)"
            showErrorAlert = true
            return
        }
        
        Task {
            isSendingBootloader = true
            do {
                let result = try await flashVM.sendBootloader(url: url)
                isSendingBootloader = false
                
                if result.success {
                    showSuccessAlert = true
                } else {
                    errorMessage = result.error ?? "未知错误"
                    showErrorAlert = true
                }
            } catch {
                isSendingBootloader = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    private var hasDevice: Bool {
        deviceVM.connectedDevice != nil
    }
}

// MARK: - 引导选择卡片
struct BootloaderSelectionCard: View {
    @Binding var bootloaderSelection: BootloaderSelection
    @Binding var bootloaderPath: URL?
    @Binding var isSendingBootloader: Bool
    let hasDevice: Bool
    let onSendBootloader: () -> Void
    let onOnePlusSelected: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("引导文件")
                    .font(.headline)
            }
            
            // 引导类型选择
            HStack(spacing: 12) {
                ForEach(BootloaderSelection.allCases) { type in
                    Button {
                        if type == .onePlus {
                            onOnePlusSelected()
                        } else {
                            bootloaderSelection = type
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.subheadline)
                            Text(type.rawValue)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(bootloaderSelection == type ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(bootloaderSelection == type ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(type == .onePlus ? 0.5 : 1.0)
                }
            }
            
            // 自定义引导文件选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择 Firehose 引导文件 (.elf/.mbn/.melf)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    if let path = bootloaderPath {
                        Text(path.lastPathComponent)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("未选择引导文件")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("选择文件") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.data, .item]
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK {
                            bootloaderPath = panel.url
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // 设备未连接提示
            if !hasDevice {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("请先连接 EDL 设备后再加载引导")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
            
            // 加载引导按钮
            Button {
                onSendBootloader()
            } label: {
                HStack {
                    if isSendingBootloader {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isSendingBootloader ? "加载中..." : "加载引导")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(bootloaderPath == nil || isSendingBootloader || !hasDevice)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - 功能卡片
struct FunctionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(disabled ? .secondary : color)
                    Spacer()
                    if disabled {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(disabled ? Color.gray.opacity(0.2) : color.opacity(0.3), lineWidth: 1)
            )
            .opacity(disabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - 操作状态视图
struct OperationStatusView: View {
    let status: String
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text(status)
                    .font(.subheadline)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.1))
        )
    }
}

// MARK: - 设备状态栏
struct DeviceStatusBar: View {
    @ObservedObject var deviceVM: DeviceViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            if let device = deviceVM.connectedDevice {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("设备已连接")
                        .font(.headline)
                    Text("\(device.name) · VID:\(String(format: "%04X", device.vendorID)) PID:\(String(format: "%04X", device.productID))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("EDL 模式")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
                
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("未检测到设备")
                        .font(.headline)
                    Text("请将设备进入 9008 EDL 模式")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("刷新") {
                    deviceVM.startMonitoring()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(deviceVM.connectedDevice != nil ? Color.green.opacity(0.05) : Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(deviceVM.connectedDevice != nil ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 日志面板（右侧竖向）
struct LogPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var autoScroll = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("操作日志")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle("自动滚动", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                
                Button("清空") {
                    appState.logs.removeAll()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // 日志内容
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(appState.logs) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                // 时间和级别
                                HStack(spacing: 4) {
                                    Text(entry.timestamp, style: .time)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    
                                    Image(systemName: entry.level.icon)
                                        .font(.system(size: 9))
                                        .foregroundStyle(entry.level.color)
                                    
                                    Text(entry.level.rawValue)
                                        .font(.system(size: 9))
                                        .foregroundStyle(entry.level.color)
                                }
                                
                                // 消息内容（完整显示）
                                Text(entry.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entry.level == .error ? Color.red.opacity(0.05) : Color.clear)
                            .id(entry.id)
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: appState.logs.count) { _ in
                    if autoScroll, let last = appState.logs.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 分区管理 Sheet
struct PartitionManagerSheet: View {
    @ObservedObject var flashVM: FlashViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("分区管理")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            PartitionListView(flashVM: flashVM)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

// MARK: - XML 刷机 Sheet
struct XMLFlashSheet: View {
    @ObservedObject var flashVM: FlashViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("XML 刷机")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            XMLFlashView(flashVM: flashVM)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
            
            AdvancedSettingsView()
                .tabItem { Label("高级", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("autoConnect") private var autoConnect = true
    @AppStorage("showNotifications") private var showNotifications = true
    
    var body: some View {
        Form {
            Section("设备") {
                Toggle("自动连接设备", isOn: $autoConnect)
                Toggle("显示通知", isOn: $showNotifications)
            }
            
            Section("日志") {
                Toggle("保存日志到文件", isOn: .constant(true))
            }
        }
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("edlTimeout") private var edlTimeout = 30.0
    @AppStorage("maxRetryCount") private var maxRetryCount = 3
    
    var body: some View {
        Form {
            Section("超时设置") {
                HStack {
                    Text("EDL 超时时间")
                    Spacer()
                    TextField("", value: $edlTimeout, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("秒")
                }
                
                HStack {
                    Text("最大重试次数")
                    Spacer()
                    TextField("", value: $maxRetryCount, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
    }
}