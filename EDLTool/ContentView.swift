import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var deviceVM = DeviceViewModel()
    @StateObject private var flashVM = FlashViewModel()
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .frame(minWidth: 200)
        } detail: {
            VStack(spacing: 0) {
                // 顶部设备状态栏
                DeviceStatusBar(deviceVM: deviceVM)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
                
                // 主内容区
                TabView(selection: $selectedTab) {
                    PartitionListView(flashVM: flashVM)
                        .tabItem {
                            Label("分区管理", systemImage: "externaldrive")
                        }
                        .tag(0)
                    
                    BootLoaderView(flashVM: flashVM)
                        .tabItem {
                            Label("引导加载", systemImage: "cpu")
                        }
                        .tag(1)
                    
                    XMLFlashView(flashVM: flashVM)
                        .tabItem {
                            Label("XML刷机", systemImage: "doc.text")
                        }
                        .tag(2)
                }
                
                Divider()
                
                // 底部日志面板
                LogPanelView()
                    .frame(height: 180)
            }
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
                
                Button {
                    // 设置
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                .help("打开设置")
            }
        }
        .onAppear {
            deviceVM.startMonitoring()
        }
        .environmentObject(deviceVM)
        .environmentObject(flashVM)
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    var body: some View {
        List(selection: $selectedTab) {
            Section("功能") {
                Label("分区管理", systemImage: "externaldrive")
                    .tag(0)
                Label("引导加载", systemImage: "cpu")
                    .tag(1)
                Label("XML刷机", systemImage: "doc.text")
                    .tag(2)
            }
            
            Section("设备") {
                if let device = deviceVM.connectedDevice {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.caption)
                                .lineLimit(1)
                            Text("已连接")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundStyle(.secondary)
                        Text("未检测到设备")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Device Status Bar
struct DeviceStatusBar: View {
    @ObservedObject var deviceVM: DeviceViewModel
    
    var body: some View {
        HStack {
            if let device = deviceVM.connectedDevice {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("设备已连接: \(device.name)")
                    .font(.subheadline)
                Text("VID:\(String(format: "%04X", device.vendorID)) PID:\(String(format: "%04X", device.productID))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(device.serialNumber ?? "N/A")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("未检测到 EDL 设备 (Qualcomm 9008)")
                    .font(.subheadline)
                Spacer()
                Text("请将设备进入 EDL 模式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(deviceVM.connectedDevice != nil ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }
}

// MARK: - Log Panel
struct LogPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var autoScroll = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("日志")
                    .font(.headline)
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
            .padding(.horizontal)
            .padding(.top, 4)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(appState.logs) { entry in
                            HStack(alignment: .top, spacing: 4) {
                                Text(entry.timestamp, style: .time)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                
                                Image(systemName: entry.level.icon)
                                    .font(.caption)
                                    .foregroundStyle(entry.level.color)
                                
                                Text(entry.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                
                                Spacer()
                            }
                            .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 8)
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

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("autoConnect") private var autoConnect = true
    @AppStorage("defaultBootloader") private var defaultBootloader = ""
    
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
