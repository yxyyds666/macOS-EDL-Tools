import Foundation

// MARK: - Partition Manager
class PartitionManager: ObservableObject {
    @Published var partitions: [Partition] = []
    @Published var isLoading = false
    
    private let edlService = EDLService()
    
    // Common partition names for quick access
    static let commonPartitions = [
        "boot", "recovery", "system", "vendor", "userdata", "cache",
        "modem", "bluetooth", "dsp", "persist", "frp", "config",
        "fsg", "fsc", "ssd", "misc", "keystore", "mdtp", "cmnlib",
        "cmnlib64", "keymaster", "prov", "devinfo", "dip", "splash"
    ]
    
    // Critical partitions that should not be modified
    static let criticalPartitions = [
        "persist", "frp", "config", "fsg", "fsc", "ssd", "keystore",
        "keymaster", "devinfo", "modemst1", "modemst2"
    ]
    
    // MARK: - Load Partitions
    func loadPartitions() async throws {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let result = try await edlService.getPartitionTable()
        
        if result.success {
            let parsed = EDLOutputParser.parsePartitionTable(result.output)
            await MainActor.run {
                self.partitions = parsed
            }
        } else {
            throw EDLError.executionFailed(result.error ?? "Failed to read partition table")
        }
    }
    
    // MARK: - Get Partition by Name
    func getPartition(named name: String) -> Partition? {
        partitions.first { $0.name == name }
    }
    
    // MARK: - Check if Partition is Critical
    func isCriticalPartition(_ partition: Partition) -> Bool {
        Self.criticalPartitions.contains(partition.name.lowercased())
    }
    
    // MARK: - Filter Partitions
    func filterPartitions(byType type: String) -> [Partition] {
        partitions.filter { $0.type.lowercased().contains(type.lowercased()) }
    }
    
    // MARK: - Get Total Size
    var totalSize: Int64 {
        partitions.reduce(0) { $0 + $1.sectors * 512 }
    }
    
    // MARK: - Backup All Partitions
    func backupAll(to directory: URL) async throws -> [String: URL] {
        var backupFiles: [String: URL] = [:]
        
        for partition in partitions {
            let backupURL = directory.appendingPathComponent("\(partition.name).bin")
            let result = try await edlService.readPartition(name: partition.name, outputURL: backupURL)
            
            if result.success {
                backupFiles[partition.name] = backupURL
            }
        }
        
        return backupFiles
    }
}

// MARK: - Partition Backup Info
struct PartitionBackup: Codable {
    let name: String
    let sector: Int64
    let sectors: Int64
    let type: String
    let backupDate: Date
    let checksum: String?
    
    init(from partition: Partition, checksum: String? = nil) {
        self.name = partition.name
        self.sector = partition.sector
        self.sectors = partition.sectors
        self.type = partition.type
        self.backupDate = Date()
        self.checksum = checksum
    }
}

// MARK: - Backup Manifest
struct BackupManifest: Codable {
    let deviceName: String
    let backupDate: Date
    let partitions: [PartitionBackup]
    let version: String = "1.0"
    
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    static func load(from url: URL) throws -> BackupManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BackupManifest.self, from: data)
    }
}
