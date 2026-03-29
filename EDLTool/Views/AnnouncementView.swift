//
//  AnnouncementView.swift
//  EDLTool
//
//  公告弹窗视图
//

import SwiftUI

struct AnnouncementView: View {
    let announcement: Announcement
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                announcementTypeIcon
                    .font(.title2)
                
                Text(announcement.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(announcementTypeColor.opacity(0.1))
            
            Divider()
            
            // 公告内容
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 公告类型标签
                    HStack {
                        announcementTypeBadge
                        
                        Spacer()
                        
                        Text(formatDate(announcement.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 公告正文
                    Text(announcement.content)
                        .font(.body)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .frame(maxHeight: 300)
            
            Divider()
            
            // 底部按钮
            HStack {
                if announcement.type == .maintenance {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("部分功能可能受影响")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("我知道了") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 450, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
    
    @ViewBuilder
    private var announcementTypeIcon: some View {
        switch announcement.type {
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case .update:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.green)
        case .maintenance:
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundColor(.red)
        }
    }
    
    private var announcementTypeColor: Color {
        switch announcement.type {
        case .info: return .blue
        case .warning: return .orange
        case .update: return .green
        case .maintenance: return .red
        }
    }
    
    @ViewBuilder
    private var announcementTypeBadge: some View {
        Text(announcementTypeText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(announcementTypeColor.opacity(0.15))
            .foregroundColor(announcementTypeColor)
            .cornerRadius(4)
    }
    
    private var announcementTypeText: String {
        switch announcement.type {
        case .info: return "通知"
        case .warning: return "警告"
        case .update: return "更新"
        case .maintenance: return "维护"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy年MM月dd日"
        return outputFormatter.string(from: date)
    }
}

// 小型公告提示条
struct AnnouncementBanner: View {
    let announcement: Announcement
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: announcementTypeIcon)
                .font(.title2)
                .foregroundColor(announcementTypeColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(announcement.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("点击查看详情")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("查看") {
                onTap()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(announcementTypeColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(announcementTypeColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var announcementTypeIcon: String {
        switch announcement.type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .update: return "arrow.down.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }
    
    private var announcementTypeColor: Color {
        switch announcement.type {
        case .info: return .blue
        case .warning: return .orange
        case .update: return .green
        case .maintenance: return .red
        }
    }
}

#Preview {
    AnnouncementView(
        announcement: Announcement(
            id: "1",
            title: "欢迎使用 EDL Tool",
            content: "这是一个公告示例。\n\n功能特性：\n• 功能 A\n• 功能 B\n• 功能 C",
            type: .info,
            isActive: true,
            createdAt: "2026-03-29T00:00:00Z",
            expiresAt: nil
        ),
        onClose: {}
    )
}
