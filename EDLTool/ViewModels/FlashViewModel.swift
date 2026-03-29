import Foundation
import Combine

// MARK: - Flash View Model
class FlashViewModel: ObservableObject {
    @Published var partitions: [Partition] = []
    @Published var selectedPartitions: Set<String> = []
    @Published var currentOperation: FlashOperation?
    @Published var operationProgress: Double = 0
    @Published var operationStatus: String = ""
    @Published var isOperating: Bool = false
    @Published var operationLog: String = ""
    
    // Bootloader
    @Published var selectedBootloader: BootloaderType = .firehose
    @Published var bootloaderPath: URL?
    @Published var bootloaders: [BootloaderInfo] = []
    
    // XML Files
    @Published var xmlFiles: [XMLFlashFile] = []
    @Published var selectedXMLFiles: Set<URL> = []
    
    private let edlService = EDLService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Partition Operations
    
    func readPartitions() async {
        await MainActor.run {
            isOperating = true
            operationStatus = "正在读取分区表..."
            operationProgress = 0
        }
        
        do {
            let result = try await edlService.getPartitionTable()
            
            await MainActor.run {
                if result.success {
                    self.partitions = parsePartitions(from: result.output)
                    self.operationStatus = "读取完成，共 \(self.partitions.count) 个分区"
                } else {
                    self.operationStatus = "读取失败: \(result.error ?? "未知错误")"
                }
                self.isOperating = false
            }
        } catch {
            await MainActor.run {
                self.operationStatus = "错误: \(error.localizedDescription)"
                self.isOperating = false
            }
        }
    }
    
    func readPartition(_ partition: Partition, to url: URL) async {
        await MainActor.run {
            isOperating = true
            operationStatus = "正在读取 \(partition.name)..."
            operationProgress = 0
        }
        
        do {
            let result = try await edlService.readPartition(
                name: partition.name,
                outputURL: url
            )
            
            await MainActor.run {
                self.operationStatus = result.success ? "读取完成" : "读取失败: \(result.error ?? "")"
                self.isOperating = false
                self.operationProgress = 1.0
            }
        } catch {
            await MainActor.run {
                self.operationStatus = "错误: \(error.localizedDescription)"
                self.isOperating = false
            }
        }
    }
    
    func writePartition(_ partition: Partition, from url: URL) async {
        await MainActor.run {
            isOperating = true
            operationStatus = "正在写入 \(partition.name)..."
            operationProgress = 0
        }
        
        do {
            let result = try await edlService.writePartition(
                name: partition.name,
                inputURL: url
            )
            
            await MainActor.run {
                self.operationStatus = result.success ? "写入完成" : "写入失败: \(result.error ?? "")"
                self.isOperating = false
                self.operationProgress = 1.0
            }
        } catch {
            await MainActor.run {
                self.operationStatus = "错误: \(error.localizedDescription)"
                self.isOperating = false
            }
        }
    }
    
    func erasePartition(_ partition: Partition) async {
        await MainActor.run {
            isOperating = true
            operationStatus = "正在擦除 \(partition.name)..."
            operationProgress = 0
        }
        
        do {
            let result = try await edlService.erasePartition(name: partition.name)
            
            await MainActor.run {
                self.operationStatus = result.success ? "擦除完成" : "擦除失败: \(result.error ?? "")"
                self.isOperating = false
                self.operationProgress = 1.0
            }
        } catch {
            await MainActor.run {
                self.operationStatus = "错误: \(error.localizedDescription)"
                self.isOperating = false
            }
        }
    }
    
    // MARK: - Bootloader Operations
    
    func sendBootloader(url: URL) async throws -> EDLResult {
        await MainActor.run {
            isOperating = true
            operationStatus = "正在发送引导文件..."
            operationProgress = 0
        }
        
        do {
            let result = try await edlService.sendBootloader(url: url)
            
            await MainActor.run {
                self.operationStatus = result.success ? "引导发送成功" : "发送失败: \(result.error ?? "")"
                self.isOperating = false
                self.operationProgress = 1.0
            }
            
            return result
        } catch {
            await MainActor.run {
                self.operationStatus = "错误: \(error.localizedDescription)"
                self.isOperating = false
            }
            throw error
        }
    }
    
    // MARK: - XML Flash Operations
    
    func addXMLFiles(_ urls: [URL]) {
        for url in urls {
            let file = XMLFlashFile(url: url)
            if !xmlFiles.contains(where: { $0.url == url }) {
                xmlFiles.append(file)
            }
        }
    }
    
    func removeXMLFile(_ file: XMLFlashFile) {
        xmlFiles.removeAll { $0.id == file.id }
        selectedXMLFiles.remove(file.url)
    }
    
    func flashXML() async {
        guard !xmlFiles.isEmpty else {
            await MainActor.run {
                operationStatus = "请先添加 XML 文件"
            }
            return
        }
        
        await MainActor.run {
            isOperating = true
            operationStatus = "正在刷入 XML..."
            operationProgress = 0
        }
        
        // Sort files: rawprogram first, then patch
        let sortedFiles = xmlFiles.sorted { file1, file2 in
            if file1.type == .rawprogram && file2.type == .patch {
                return true
            }
            return false
        }
        
        let urls = sortedFiles.map { $0.url }
        
        do {
            let result = try await edlService.flashXMLFiles(urls: urls) { progress in
                Task { @MainActor in
                    self.operationProgress = progress
                }
            }
            
            await MainActor.run {
                self.operationStatus = result.success ? "刷入完成" : "刷入失败: \(result.error ?? "")"
                self.isOperating = false
                self.operationProgress = 1.0
            }
        } catch {
            await MainActor.run {
                self.operationStatus = "错误: \(error.localizedDescription)"
                self.isOperating = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func parsePartitions(from output: String) -> [Partition] {
        var partitions: [Partition] = []
        
        // Parse partition table output
        // Expected format: partition_name sector sectors type
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let components = line.split(separator: " ").map(String.init)
            if components.count >= 4 {
                let partition = Partition(
                    id: components[0],
                    name: components[0],
                    sector: Int64(components[1]) ?? 0,
                    sectors: Int64(components[2]) ?? 0,
                    type: components[3],
                    readOnly: components.count > 4 && components[4] == "RO"
                )
                partitions.append(partition)
            }
        }
        
        return partitions
    }
    
    // MARK: - Cancel Operation
    func cancelOperation() {
        edlService.cancelCurrentOperation()
        isOperating = false
        operationStatus = "操作已取消"
    }
}

// MARK: - Bootloader Info
struct BootloaderInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: BootloaderType
    let url: URL
}