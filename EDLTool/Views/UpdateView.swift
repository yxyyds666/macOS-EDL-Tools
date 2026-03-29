//
//  UpdateView.swift
//  EDLTool
//
//  更新弹窗视图
//

import SwiftUI

struct UpdateView: View {
    let updateInfo: UpdateInfo
    let onDownload: () -> Void
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // 标题
            Text("发现新版本")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            Text("v\(updateInfo.latestVersion)")
                .font(.title3)
                .foregroundColor(.blue)
                .padding(.bottom, 16)
            
            // 版本信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前版本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("v\(updateInfo.currentVersion)")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("最新版本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("v\(updateInfo.latestVersion)")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            // 更新日志
            if !updateInfo.releaseNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("更新内容")
                        .font(.headline)
                        .padding(.top, 16)
                    
                    ScrollView {
                        Text(updateInfo.releaseNotes)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // 按钮
            HStack(spacing: 12) {
                Button("稍后提醒") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("立即下载") {
                    onDownload()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 24)
        }
        .frame(width: 400, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isAnimating = true
        }
    }
}

// 简化的更新提示条
struct UpdateBanner: View {
    let updateInfo: UpdateInfo
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("有新版本可用")
                    .font(.headline)
                Text("v\(updateInfo.currentVersion) → v\(updateInfo.latestVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("更新") {
                onTap()
            }
            .buttonStyle(.borderedProminent)
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
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    UpdateView(
        updateInfo: UpdateInfo(
            currentVersion: "1.0.0",
            latestVersion: "1.1.0",
            releaseNotes: "• 新增功能 A\n• 修复问题 B\n• 优化性能 C",
            downloadURL: "https://github.com",
            isNewVersionAvailable: true
        ),
        onDownload: {},
        onDismiss: {}
    )
}
