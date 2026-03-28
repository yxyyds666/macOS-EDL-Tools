import SwiftUI

// MARK: - Bootloader View
struct BootLoaderView: View {
    @ObservedObject var flashVM: FlashViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var selectedBootloaderType: BootloaderType = .firehose
    @State private var customBootloaderURL: URL?
    @State private var showingFilePicker = false
    @State private var showingSuccessAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("引导加载")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("选择并发送引导文件到 EDL 设备")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                    .padding(.horizontal)
                
                // Bootloader Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("引导类型")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(BootloaderType.allCases) { type in
                            BootloaderTypeCard(
                                type: type,
                                isSelected: selectedBootloaderType == type,
                                action: {
                                    selectedBootloaderType = type
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Custom Bootloader Selection
                if selectedBootloaderType == .custom {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("自定义引导文件")
                            .font(.headline)
                        
                        HStack {
                            if let url = customBootloaderURL {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.lastPathComponent)
                                        .font(.body)
                                    Text(url.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("重新选择") {
                                    showingFilePicker = true
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Text("未选择文件")
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button("选择文件") {
                                    showingFilePicker = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                // OnePlus Special Options
                if selectedBootloaderType == .oneplusAuth {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("一加免授权模式")
                            .font(.headline)
                        
                        Text("此模式无需引导文件即可直接连接一加设备的 EDL 模式。支持的设备包括：")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(["OnePlus 3/3T", "OnePlus 5/5T", "OnePlus 6/6T", "OnePlus 7/7T 系列", "OnePlus 8/8T/8 Pro", "OnePlus 9/9 Pro", "OnePlus Nord 系列"], id: \.self) { device in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text(device)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                // UEFI Options
                if selectedBootloaderType == .edlUefi {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("UEFI 引导")
                            .font(.headline)
                        
                        Text("选择 .efi 引导文件用于特殊设备的 EDL 模式。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            if let url = customBootloaderURL {
                                Text(url.lastPathComponent)
                                    .font(.body)
                                Spacer()
                                Button("重新选择") {
                                    showingFilePicker = true
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Text("未选择 .efi 文件")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("选择 .efi 文件") {
                                    showingFilePicker = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                // Action Button
                VStack(spacing: 16) {
                    if flashVM.isOperating {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(flashVM.operationStatus)
                                .font(.subheadline)
                            
                            Button("取消") {
                                flashVM.cancelOperation()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                    } else {
                        Button {
                            sendBootloaderAction()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "cpu.fill")
                                Text(buttonTitle)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSendBootloader)
                        .opacity(canSendBootloader ? 1 : 0.5)
                    }
                }
                .padding(.horizontal)
                
                // Status Info
                if deviceVM.connectedDevice != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("设备已连接，可以发送引导")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("请先连接 EDL 设备")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: selectedBootloaderType == .edlUefi ? [.filenameExtension("efi")] : [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                customBootloaderURL = urls.first
            case .failure(let error):
                appState.addLog("选择文件失败: \(error.localizedDescription)", level: .error)
            }
        }
        .alert("操作结果", isPresented: $showingSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var buttonTitle: String {
        switch selectedBootloaderType {
        case .oneplusAuth:
            return "连接一加免授权模式"
        case .firehose, .sahara:
            return "发送 Firehose 引导"
        case .edlUefi:
            return "发送 UEFI 引导"
        case .custom:
            return "发送自定义引导"
        }
    }
    
    private var canSendBootloader: Bool {
        guard deviceVM.connectedDevice != nil else { return false }
        
        switch selectedBootloaderType {
        case .oneplusAuth:
            return true
        case .firehose, .sahara, .edlUefi, .custom:
            return customBootloaderURL != nil
        }
    }
    
    private func sendBootloaderAction() {
        Task {
            switch selectedBootloaderType {
            case .oneplusAuth:
                appState.addLog("正在连接一加免授权模式...")
                await flashVM.connectOnePlusAuth()
                
            case .firehose, .sahara, .edlUefi, .custom:
                guard let url = customBootloaderURL else { return }
                appState.addLog("正在发送引导文件: \(url.lastPathComponent)")
                await flashVM.sendBootloader(url: url)
            }
            
            alertMessage = flashVM.operationStatus
            showingSuccessAlert = true
            appState.addLog(flashVM.operationStatus, level: flashVM.operationStatus.contains("成功") ? .success : .error)
        }
    }
}

// MARK: - Bootloader Type Card
struct BootloaderTypeCard: View {
    let type: BootloaderType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .accent)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                
                Text(type.rawValue)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(type.description)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        switch type {
        case .firehose: return "flame"
        case .sahara: return "sun.max"
        case .edlUefi: return "cpu"
        case .oneplusAuth: return "plus.circle"
        case .custom: return "doc.badge.plus"
        }
    }
}

// MARK: - UTType Extension
extension UTType {
    static func filenameExtension(_ ext: String) -> UTType {
        UTType(filenameExtension: ext, conformingTo: .data) ?? .data
    }
}
