import SwiftUI

// MARK: - Partition List View
struct PartitionListView: View {
    @ObservedObject var flashVM: FlashViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var searchText = ""
    @State private var showingReadSheet = false
    @State private var showingWriteSheet = false
    @State private var showingEraseConfirm = false
    @State private var selectedPartition: Partition?
    @State private var selectedFileURL: URL?
    
    var filteredPartitions: [Partition] {
        if searchText.isEmpty {
            return flashVM.partitions
        }
        return flashVM.partitions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button {
                    Task {
                        appState.addLog("正在读取分区表...")
                        await flashVM.readPartitions()
                        appState.addLog("读取完成，共 \(flashVM.partitions.count) 个分区", level: .success)
                    }
                } label: {
                    Label("读取分区", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(deviceVM.connectedDevice == nil || flashVM.isOperating)
                
                Spacer()
                
                Text("共 \(flashVM.partitions.count) 个分区")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索分区名称...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            if flashVM.isOperating && flashVM.partitions.isEmpty {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(flashVM.operationStatus)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if flashVM.partitions.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("未加载分区表")
                        .font(.headline)
                    Text("请连接设备后点击\"读取分区\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Partition list
                Table(filteredPartitions, selection: $flashVM.selectedPartitions) {
                    TableColumn("分区名称") { partition in
                        HStack(spacing: 8) {
                            Image(systemName: partition.readOnly ? "lock.fill" : "externaldrive")
                                .foregroundStyle(partition.readOnly ? .orange : .blue)
                            Text(partition.name)
                                .fontWeight(.medium)
                        }
                    }
                    .width(min: 120, max: 200)
                    
                    TableColumn("大小") { partition in
                        Text(partition.formattedSize)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(100)
                    
                    TableColumn("类型") { partition in
                        Text(partition.type)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .width(100)
                    
                    TableColumn("起始扇区") { partition in
                        Text("\(partition.sector)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .width(120)
                    
                    TableColumn("操作") { partition in
                        HStack(spacing: 4) {
                            Button {
                                selectedPartition = partition
                                showingReadSheet = true
                            } label: {
                                Image(systemName: "arrow.down.circle")
                                    .help("读取分区")
                            }
                            .buttonStyle(.borderless)
                            
                            Button {
                                selectedPartition = partition
                                showingWriteSheet = true
                            } label: {
                                Image(systemName: "arrow.up.circle")
                                    .help("写入分区")
                            }
                            .buttonStyle(.borderless)
                            .disabled(partition.readOnly)
                            
                            Button {
                                selectedPartition = partition
                                showingEraseConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .help("擦除分区")
                            }
                            .buttonStyle(.borderless)
                            .disabled(partition.readOnly)
                        }
                    }
                    .width(100)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .fileImporter(
            isPresented: $showingWriteSheet,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        appState.addLog("正在写入分区 \(selectedPartition?.name ?? "")...")
                        await flashVM.writePartition(selectedPartition!, from: url)
                        appState.addLog("写入完成", level: .success)
                    }
                }
            case .failure(let error):
                appState.addLog("选择文件失败: \(error.localizedDescription)", level: .error)
            }
        }
        .fileExporter(
            isPresented: $showingReadSheet,
            document: BinaryFileDocument(data: Data()),
            contentType: .data,
            defaultFilename: "\(selectedPartition?.name ?? "partition").bin"
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    appState.addLog("正在读取分区 \(selectedPartition?.name ?? "")...")
                    await flashVM.readPartition(selectedPartition!, to: url)
                    appState.addLog("读取完成", level: .success)
                }
            case .failure(let error):
                appState.addLog("选择文件失败: \(error.localizedDescription)", level: .error)
            }
        }
        .alert("确认擦除", isPresented: $showingEraseConfirm) {
            Button("取消", role: .cancel) { }
            Button("擦除", role: .destructive) {
                if let partition = selectedPartition {
                    Task {
                        appState.addLog("正在擦除分区 \(partition.name)...")
                        await flashVM.erasePartition(partition)
                        appState.addLog("擦除完成", level: .success)
                    }
                }
            }
        } message: {
            Text("确定要擦除分区 \"\(selectedPartition?.name ?? "")\" 吗？此操作不可恢复！")
        }
    }
}

// MARK: - Binary File Document
struct BinaryFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// Import UTType
import UniformTypeIdentifiers
