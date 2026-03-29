//
//  AnnouncementService.swift
//  EDLTool
//
//  公告服务
//

import Foundation

struct Announcement: Codable {
    let id: String
    let title: String
    let content: String
    let type: AnnouncementType
    let isActive: Bool
    let createdAt: String
    let expiresAt: String?
    
    enum AnnouncementType: String, Codable {
        case info = "info"
        case warning = "warning"
        case update = "update"
        case maintenance = "maintenance"
    }
}

@MainActor
class AnnouncementService: ObservableObject {
    static let shared = AnnouncementService()
    
    @Published var currentAnnouncement: Announcement?
    @Published var isLoading = false
    @Published var hasUnreadAnnouncement = false
    
    // 公告配置文件 URL (可以从远程获取，目前使用本地)
    private let announcementURL = "https://raw.githubusercontent.com/yxyyds666/macOS-EDL-Tools/main/announcement.json"
    
    // 本地存储的已读公告 ID
    private let readAnnouncementsKey = "readAnnouncements"
    
    private init() {
        loadCachedAnnouncement()
    }
    
    func fetchAnnouncement() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // 首先尝试从远程获取
        if let remoteAnnouncement = await fetchRemoteAnnouncement() {
            // 只有未读时才更新状态
            if shouldShowAnnouncement(remoteAnnouncement) {
                currentAnnouncement = remoteAnnouncement
                hasUnreadAnnouncement = true
            }
            return
        }
        
        // 如果远程获取失败，使用本地公告
        if let localAnnouncement = getLocalAnnouncement() {
            if shouldShowAnnouncement(localAnnouncement) {
                currentAnnouncement = localAnnouncement
                hasUnreadAnnouncement = true
            }
        }
    }
    
    private func fetchRemoteAnnouncement() async -> Announcement? {
        guard let url = URL(string: announcementURL) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let announcement = try JSONDecoder().decode(Announcement.self, from: data)
            
            // 缓存到本地
            cacheAnnouncement(announcement)
            
            return announcement
        } catch {
            print("Failed to fetch announcement: \(error)")
            return nil
        }
    }
    
    private func getLocalAnnouncement() -> Announcement? {
        // 本地硬编码的公告（作为备用）
        let localAnnouncement = Announcement(
            id: "local-1",
            title: "欢迎使用 EDL Tool",
            content: """
            macOS EDL Tool 是一款专为 macOS 设计的 Qualcomm EDL 工具。
            
            功能特性：
            • 自动检测 EDL (9008) 设备
            • 发送 Firehose 引导加载器
            • 分区列表读取和管理
            • 支持多种 Qualcomm 芯片平台
            
            注意事项：
            • 请确保使用高质量 USB 数据线
            • OPPO/一加设备 VIP 认证功能开发中
            • 操作有风险，请提前备份数据
            """,
            type: .info,
            isActive: true,
            createdAt: "2026-03-29",
            expiresAt: nil
        )
        
        return localAnnouncement
    }
    
    private func shouldShowAnnouncement(_ announcement: Announcement) -> Bool {
        guard announcement.isActive else { return false }
        
        // 检查是否过期
        if let expiresAt = announcement.expiresAt {
            let formatter = ISO8601DateFormatter()
            guard let expiryDate = formatter.date(from: expiresAt) else { return true }
            if Date() > expiryDate { return false }
        }
        
        // 检查是否已读
        let readIDs = getReadAnnouncementIDs()
        return !readIDs.contains(announcement.id)
    }
    
    func markAsRead() {
        guard let announcement = currentAnnouncement else { return }
        
        var readIDs = getReadAnnouncementIDs()
        if !readIDs.contains(announcement.id) {
            readIDs.append(announcement.id)
            UserDefaults.standard.set(readIDs, forKey: readAnnouncementsKey)
        }
        
        hasUnreadAnnouncement = false
    }
    
    private func getReadAnnouncementIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: readAnnouncementsKey) ?? []
    }
    
    private func cacheAnnouncement(_ announcement: Announcement) {
        if let data = try? JSONEncoder().encode(announcement) {
            UserDefaults.standard.set(data, forKey: "cachedAnnouncement")
        }
    }
    
    private func loadCachedAnnouncement() {
        guard let data = UserDefaults.standard.data(forKey: "cachedAnnouncement"),
              let announcement = try? JSONDecoder().decode(Announcement.self, from: data),
              shouldShowAnnouncement(announcement) else {
            return
        }
        
        currentAnnouncement = announcement
        hasUnreadAnnouncement = true
    }
    
    // 重置所有已读状态（用于测试）
    func resetReadStatus() {
        UserDefaults.standard.removeObject(forKey: readAnnouncementsKey)
        hasUnreadAnnouncement = true
    }
}
