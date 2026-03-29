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
    private func executeEDL(args: [String], timeout: TimeInterval = 60) async throws -> EDLResult {
        isCancelled = false
        let startTime = Date()
        
        let edlPath = edlBinaryPath
        
        // Check if embedded binary exists
        guard FileManager.default.fileExists(atPath: edlPath.path) else {
            throw EDLError.executionFailed("EDL 二进制文件未找到: \(edlPath.path)")
        }
        
        // Ensure logs directory exists (required by edl tool)
        let logsDir = FileManager.default.currentDirectoryPath + "/logs"
        try? FileManager.default.createDirectory(atPath: logsDir, withIntermediateDirectories: true)
        
        // Log the full command
        let fullCommand = "\(edlPath.path) \(args.joined(separator: " "))"
        AppState.shared.addLog("执行命令: \(fullCommand)", level: .info)
        
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
        
        // Read output asynchronously and log
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.append(data)
                // Log output in real-time
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    for line in lines {
                        AppState.shared.addLog("[EDL] \(line)", level: .info)
                    }
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.append(data)
                // Log error in real-time
                if let error = String(data: data, encoding: .utf8) {
                    let lines = error.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    for line in lines {
                        AppState.shared.addLog("[EDL] \(line)", level: .warning)
                    }
                }
            }
        }
        
        do {
            try process.run()
            
            // 使用简化的超时等待
            let terminationStatus = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                // 超时检查
                let timeoutItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                        continuation.resume(throwing: EDLError.timeout)
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
                
                // 在后台线程等待进程结束
                DispatchQueue.global().async {
                    process.waitUntilExit()
                    timeoutItem.cancel()
                    if !timeoutItem.isCancelled {
                        continuation.resume(returning: process.terminationStatus)
                    }
                }
            }
            
            let output = String(data: outputData as Data, encoding: .utf8) ?? ""
            let error = String(data: errorData as Data, encoding: .utf8)
            let duration = Date().timeIntervalSince(startTime)
            
            let success = terminationStatus == 0 && !isCancelled
            
            // Log result
            if success {
                AppState.shared.addLog("命令执行完成 (耗时: \(String(format: "%.1f", duration))秒)", level: .success)
            } else {
                AppState.shared.addLog("命令执行失败 (退出码: \(terminationStatus))", level: .error)
            }
            
            return EDLResult(success: success, output: output, error: error, duration: duration)
            
        } catch let error as EDLError {
            // 超时，终止进程
            if process.isRunning {
                process.terminate()
            }
            AppState.shared.addLog("命令超时 (\(Int(timeout))秒)", level: .error)
            throw error
        } catch {
            if process.isRunning {
                process.terminate()
            }
            AppState.shared.addLog("进程启动失败: \(error.localizedDescription)", level: .error)
            throw EDLError.executionFailed(error.localizedDescription)
        }
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
        // edl 需要 nop 子命令来发送引导
        return try await executeEDL(args: [
            "nop", "--loader", url.path
        ], timeout: 60)
    }
    
    func connect(device: String? = nil) async throws -> EDLResult {
        // edl 需要 nop 子命令来连接设备
        var args = ["nop"]
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