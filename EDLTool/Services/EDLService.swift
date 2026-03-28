import Foundation

// MARK: - EDL Service
class EDLService {
    
    private var process: Process?
    private var isCancelled = false
    
    // Path to embedded EDL binary
    private var edlBinaryPath: URL {
        Bundle.main.url(forResource: "edl_bin", withExtension: nil) ??
        Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/edl_bin")
    }
    
    // MARK: - Execute EDL Command
    private func executeEDL(args: [String], timeout: TimeInterval = 300) async throws -> EDLResult {
        isCancelled = false
        let startTime = Date()
        
        let edlPath = edlBinaryPath
        
        // Check if embedded binary exists
        guard FileManager.default.fileExists(atPath: edlPath.path) else {
            throw EDLError.executionFailed("EDL 二进制文件未找到: \(edlPath.path)")
        }
        
        let process = Process()
        process.executableURL = edlPath
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice
        
        self.process = process
        
        let outputData = NSMutableData()
        let errorData = NSMutableData()
        
        // Read output asynchronously
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.append(data)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.append(data)
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw EDLError.executionFailed(error.localizedDescription)
        }
        
        let output = String(data: outputData as Data, encoding: .utf8) ?? ""
        let error = String(data: errorData as Data, encoding: .utf8)
        let duration = Date().timeIntervalSince(startTime)
        
        let success = process.terminationStatus == 0 && !isCancelled
        
        return EDLResult(success: success, output: output, error: error, duration: duration)
    }
    
    // MARK: - Partition Operations
    
    func getPartitionTable() async throws -> EDLResult {
        return try await executeEDL(args: ["printgpt"], timeout: 30)
    }
    
    func readPartition(name: String, outputURL: URL) async throws -> EDLResult {
        return try await executeEDL(args: [
            "r", name, outputURL.path
        ], timeout: 600)
    }
    
    func writePartition(name: String, inputURL: URL) async throws -> EDLResult {
        return try await executeEDL(args: [
            "w", name, inputURL.path
        ], timeout: 600)
    }
    
    func erasePartition(name: String) async throws -> EDLResult {
        return try await executeEDL(args: ["e", name], timeout: 60)
    }
    
    // MARK: - Bootloader Operations
    
    func sendBootloader(url: URL) async throws -> EDLResult {
        return try await executeEDL(args: [
            "--loader", url.path
        ], timeout: 60)
    }
    
    func connectOnePlusAuth() async throws -> EDLResult {
        // OnePlus EDL auth bypass - try different methods
        let result = try await executeEDL(args: ["--search"], timeout: 30)
        return result
    }
    
    func connect(device: String? = nil) async throws -> EDLResult {
        var args = ["--search"]
        if let device = device {
            args.append(contentsOf: ["--portname", device])
        }
        return try await executeEDL(args: args, timeout: 30)
    }
    
    // MARK: - XML Flash Operations
    
    func flashXMLFiles(urls: [URL], progress: @escaping (Double) -> Void) async throws -> EDLResult {
        // Flash using rawprogram and patch files
        // EDL binary supports: flash <rawprogram> <patch>
        var args = ["flash"]
        
        for url in urls {
            args.append(url.path)
        }
        
        // Track progress
        Task {
            var currentProgress: Double = 0
            while currentProgress < 1.0 && !isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                currentProgress += 0.02
                progress(min(currentProgress, 0.95))
            }
        }
        
        let result = try await executeEDL(args: args, timeout: 1200)
        progress(1.0)
        return result
    }
    
    // MARK: - Backup/Restore
    
    func backupAll(to directory: URL) async throws -> EDLResult {
        return try await executeEDL(args: [
            "rl", directory.path
        ], timeout: 1800)
    }
    
    func restoreAll(from directory: URL) async throws -> EDLResult {
        return try await executeEDL(args: [
            "wl", directory.path
        ], timeout: 1800)
    }
    
    // MARK: - Cancel Operation
    func cancelCurrentOperation() {
        isCancelled = true
        process?.terminate()
    }
}

// MARK: - EDL Error
enum EDLError: LocalizedError {
    case deviceNotFound
    case connectionFailed
    case executionFailed(String)
    case timeout
    case permissionDenied
    case invalidPartition
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "未找到 EDL 设备"
        case .connectionFailed:
            return "连接设备失败"
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .timeout:
            return "操作超时"
        case .permissionDenied:
            return "权限被拒绝"
        case .invalidPartition:
            return "无效的分区"
        }
    }
}

// MARK: - EDL Output Parser
class EDLOutputParser {
    
    static func parsePartitionTable(_ output: String) -> [Partition] {
        var partitions: [Partition] = []
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Skip empty lines and headers
            guard !line.isEmpty, !line.contains("Partition") else { continue }
            
            // Parse format: Name | Sector | Sectors | Type
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            
            if components.count >= 4 {
                let name = String(components[0])
                let sector = Int64(String(components[1])) ?? 0
                let sectors = Int64(String(components[2])) ?? 0
                let type = String(components[3])
                let readOnly = components.count > 4 && String(components[4]).uppercased() == "RO"
                
                let partition = Partition(
                    id: name,
                    name: name,
                    sector: sector,
                    sectors: sectors,
                    type: type,
                    readOnly: readOnly
                )
                partitions.append(partition)
            }
        }
        
        return partitions.sorted { $0.sector < $1.sector }
    }
    
    static func parseDeviceInfo(_ output: String) -> [String: String] {
        var info: [String: String] = [:]
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                info[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return info
    }
}