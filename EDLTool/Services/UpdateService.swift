//
//  UpdateService.swift
//  EDLTool
//
//  版本更新检测服务
//

import Foundation
import AppKit

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
}

struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String
    let downloadURL: String
    let isNewVersionAvailable: Bool
}

@MainActor
class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    @Published var isChecking = false
    @Published var updateInfo: UpdateInfo?
    @Published var lastCheckDate: Date?
    
    private let githubRepo = "yxyyds666/macOS-EDL-Tools"
    private let releasesURL = "https://api.github.com/repos/yxyyds666/macOS-EDL-Tools/releases/latest"
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private init() {}
    
    func checkForUpdates() async throws -> UpdateInfo? {
        guard !isChecking else { return nil }
        
        isChecking = true
        defer { 
            Task { @MainActor in
                self.isChecking = false
                self.lastCheckDate = Date()
            }
        }
        
        guard let url = URL(string: releasesURL) else {
            throw UpdateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw UpdateError.httpError(httpResponse.statusCode)
        }
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
        let isNewVersion = compareVersions(currentVersion, latestVersion) == .orderedAscending
        
        let info = UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseNotes: release.body,
            downloadURL: release.htmlUrl,
            isNewVersionAvailable: isNewVersion
        )
        
        await MainActor.run {
            self.updateInfo = info
        }
        
        return info
    }
    
    func checkForUpdatesSilently() async {
        do {
            _ = try await checkForUpdates()
        } catch {
            // 静默检查，忽略错误
            print("Update check failed: \(error.localizedDescription)")
        }
    }
    
    private func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let v1Components = v1.split(separator: ".").compactMap { Int($0) }
        let v2Components = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Val = i < v1Components.count ? v1Components[i] : 0
            let v2Val = i < v2Components.count ? v2Components[i] : 0
            
            if v1Val < v2Val { return .orderedAscending }
            if v1Val > v2Val { return .orderedDescending }
        }
        
        return .orderedSame
    }
    
    func openDownloadPage() {
        guard let url = URL(string: "https://github.com/yxyyds666/macOS-EDL-Tools/releases/latest") else { return }
        NSWorkspace.shared.open(url)
    }
}

enum UpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError:
            return "解析错误"
        }
    }
}
