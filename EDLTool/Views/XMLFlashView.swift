import SwiftUI
import UniformTypeIdentifiers

// MARK: - XML Flash View
struct XMLFlashView: View {
    @ObservedObject var flashVM: FlashViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var firmwareFolder: URL?
    @State private var showingSuccessAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("XML 刷机")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("选择 rawprogram*.xml 和 patch*.xml 文件进行刷机")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    showingFolderPicker = true
                } label: {
                    Label("选择固件文件夹", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                
                Button {
                    showingFilePicker = true
                } label: {
                    Label("添加 XML 文件", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Main Content
            if flashVM.xmlFiles.isEmpty {
                // Empty State
                VStack(spacing: 24) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("未添加 XML 文件")
                            .font(.headline)
                        Text("点击上方按钮添加 rawprogram*.xml 或 patch*.xml 文件")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        showingFolderPicker = true
                    } label: {
                        Label("选择包含 XML 文件的固件文件夹", systemImage: "folder")
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // XML File List
                VStack(spacing: 0) {
                    // File List Header
                    HStack {
                        Text("文件列表")
                            .font(.headline)
                        Spacer()
                        Text("\(flashVM.xmlFiles.count) 个文件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                    
                    // File List
                    List {
                        ForEach(flashVM.xmlFiles) { file in
                            XMLFileRow(file: file, isSelected: flashVM.selectedXMLFiles.contains(file.url)) {
                                if flashVM.selectedXMLFiles.contains(file.url) {
                                    flashVM.selectedXMLFiles.remove(file.url)
                                } else {
                                    flashVM.selectedXMLFiles.insert(file.url)
                                }
                            } onRemove: {
                                flashVM.removeXMLFile(file)
                            }
                        }
                    }
                    .listStyle(.inset)
                    
                    Divider()
                    
                    // Flash Order Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("刷机顺序")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 16) {
                            Label("1. rawprogram*.xml", systemImage: "number.circle")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label("2. patch*.xml", systemImage: "number.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                        .padding(.leading, 24)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                }
            }
            
            Divider()
            
            // Bottom Action Bar
            HStack {
                // Device Status
                if let device = deviceVM.connectedDevice {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("设备已连接")
                            .font(.caption)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("设备未连接")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                if flashVM.isOperating {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(flashVM.operationStatus)
                            .font(.subheadline)
                        
                        Button("取消") {
                            flashVM.cancelOperation()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button("清空列表") {
                        flashVM.xmlFiles.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        Task {
                            await performFlash()
                        }
                    } label: {
                        Label("开始刷机", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(deviceVM.connectedDevice == nil || flashVM.xmlFiles.isEmpty)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                flashVM.addXMLFiles(urls)
                appState.addLog("添加了 \(urls.count) 个 XML 文件", level: .success)
            case .failure(let error):
                appState.addLog("选择文件失败: \(error.localizedDescription)", level: .error)
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folder = urls.first {
                    scanFolderForXML(folder)
                }
            case .failure(let error):
                appState.addLog("选择文件夹失败: \(error.localizedDescription)", level: .error)
            }
        }
        .alert("刷机完成", isPresented: $showingSuccessAlert) {
            Button("确定") { }
        } message: {
            Text(flashVM.operationStatus)
        }
    }
    
    private func scanFolderForXML(_ folder: URL) {
        var xmlFiles: [URL] = []
        
        if let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let filename = fileURL.lastPathComponent.lowercased()
                if filename.hasSuffix(".xml") && 
                   (filename.contains("rawprogram") || filename.contains("patch")) {
                    xmlFiles.append(fileURL)
                }
            }
        }
        
        flashVM.addXMLFiles(xmlFiles)
        appState.addLog("从文件夹扫描到 \(xmlFiles.count) 个 XML 文件", level: .info)
    }
    
    private func performFlash() async {
        appState.addLog("开始 XML 刷机...")
        appState.addLog("共 \(flashVM.xmlFiles.count) 个文件待刷入")
        
        await flashVM.flashXML()
        
        let success = flashVM.operationStatus.contains("完成")
        appState.addLog(
            flashVM.operationStatus,
            level: success ? .success : .error
        )
        
        if success {
            showingSuccessAlert = true
        }
    }
}

// MARK: - XML File Row
struct XMLFileRow: View {
    let file: XMLFlashFile
    let isSelected: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .accent : .secondary)
            }
            .buttonStyle(.plain)
            
            // File type icon
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(file.type.color)
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(file.type.description)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(file.type.color.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(file.url.deletingLastPathComponent().lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Remove button
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - UTType Extension for XML
extension UTType {
    static var xml: UTType {
        UTType(filenameExtension: "xml", conformingTo: .text) ?? .xml
    }
}
