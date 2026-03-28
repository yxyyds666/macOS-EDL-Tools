import Foundation
import SwiftUI

// MARK: - USB Device Model
struct USBDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let vendorID: Int
    let productID: Int
    let serialNumber: String?
    let locationID: Int
    let manufacturer: String?
    
    var isQualcommEDL: Bool {
        // Qualcomm EDL mode: VID=0x05C6, PID=0x9008
        return vendorID == 0x05C6 && productID == 0x9008
    }
    
    var isEDLMode: Bool {
        // Common EDL PIDs
        let edlPIDs = [0x9008, 0x900E, 0x901D, 0x9025]
        return vendorID == 0x05C6 && edlPIDs.contains(productID)
    }
    
    static func == (lhs: USBDevice, rhs: USBDevice) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Partition Model
struct Partition: Identifiable, Hashable {
    let id: String
    let name: String
    let sector: Int64
    let sectors: Int64
    let type: String
    let readOnly: Bool
    var isSelected: Bool = false
    
    var sizeInMB: Double {
        Double(sectors * 512) / (1024 * 1024)
    }
    
    var sizeInGB: Double {
        Double(sectors * 512) / (1024 * 1024 * 1024)
    }
    
    var formattedSize: String {
        let size = Double(sectors * 512)
        if size >= 1024 * 1024 * 1024 {
            return String(format: "%.2f GB", size / (1024 * 1024 * 1024))
        } else if size >= 1024 * 1024 {
            return String(format: "%.2f MB", size / (1024 * 1024))
        } else if size >= 1024 {
            return String(format: "%.2f KB", size / 1024)
        } else {
            return String(format: "%d B", Int(size))
        }
    }
}

// MARK: - Bootloader Type
enum BootloaderType: String, CaseIterable, Identifiable {
    case firehose = "Firehose"
    case sahara = "Sahara"
    case edlUefi = "EDL UEFI"
    case oneplusAuth = "一加免授权"
    case custom = "自定义"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .firehose:
            return "通用 Firehose 引导 (prog_emmc_firehose_*.mbn)"
        case .sahara:
            return "Sahara 协议引导"
        case .edlUefi:
            return "UEFI 引导文件 (*.efi)"
        case .oneplusAuth:
            return "一加设备免授权 9008 模式"
        case .custom:
            return "用户自定义引导文件"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .firehose, .sahara:
            return "mbn"
        case .edlUefi:
            return "efi"
        case .oneplusAuth:
            return "mbn"
        case .custom:
            return "*"
        }
    }
}

// MARK: - Flash Operation
struct FlashOperation: Identifiable {
    let id = UUID()
    let type: FlashType
    let partition: String?
    let filePath: String?
    let status: FlashStatus
    let progress: Double
    let startTime: Date
    var endTime: Date?
    var error: String?
    
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}

enum FlashType {
    case readPartition
    case writePartition
    case erasePartition
    case flashXML
    case sendBootloader
    case backupAll
    case restoreAll
}

enum FlashStatus {
    case pending
    case running
    case completed
    case failed
    case cancelled
    
    var color: Color {
        switch self {
        case .pending: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "stop.circle"
        }
    }
}

// MARK: - XML File Info
struct XMLFlashFile: Identifiable {
    let id = UUID()
    let url: URL
    let type: XMLFileType
    let name: String
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        
        if name.contains("rawprogram") {
            self.type = .rawprogram
        } else if name.contains("patch") {
            self.type = .patch
        } else {
            self.type = .unknown
        }
    }
}

enum XMLFileType {
    case rawprogram
    case patch
    case unknown
    
    var color: Color {
        switch self {
        case .rawprogram: return .blue
        case .patch: return .purple
        case .unknown: return .secondary
        }
    }
    
    var description: String {
        switch self {
        case .rawprogram: return "分区程序"
        case .patch: return "补丁文件"
        case .unknown: return "未知类型"
        }
    }
}

// MARK: - EDL Command Result
struct EDLResult {
    let success: Bool
    let output: String
    let error: String?
    let duration: TimeInterval
    
    var message: String {
        if success {
            return output
        } else {
            return error ?? "未知错误"
        }
    }
}
