import Foundation

// MARK: - File Manager Extensions
extension FileManager {
    func getDocumentsDirectory() -> URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func getApplicationSupportDirectory() -> URL {
        urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    
    func ensureDirectoryExists(at url: URL) throws {
        if !fileExists(atPath: url.path) {
            try createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - String Extensions
extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func asHexString() -> String {
        map { String(format: "%02X", $0.asciiValue ?? 0) }.joined()
    }
}

// MARK: - Data Extensions
extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }
}

// MARK: - Color Extensions
import SwiftUI

extension Color {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
