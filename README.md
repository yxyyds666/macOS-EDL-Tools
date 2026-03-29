# macOS EDL Tools

一款专为 macOS 设计的 Qualcomm EDL (Emergency Download Mode) 工具，支持设备检测、引导加载器发送和分区管理。

## 功能特性

- 自动检测 EDL (9008) 设备
- 发送 Firehose 引导加载器
- 分区列表读取和管理
- 支持多种 Qualcomm 芯片平台
- 原生 macOS SwiftUI 界面

## 支持的芯片平台

| 平台 | 设备示例 |
|------|----------|
| SDM845 | 小米 8、一加 6 |
| SM8350 (888) | 小米 11、一加 9 |
| SM8475 (8+ Gen1) | 小米 12S、一加 10T |
| SM8550 (8 Gen2) | 小米 13、一加 11 |
| SM8650 (8 Gen3) | 小米 14、一加 12 |
| SM8750 (8 Elite) | 一加 13 |
| SM6115/662 | 红米 Note 9/10 |
| SM6375/695 | 红米 Note 11/12 |
| 更多平台... | |

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0 或更高版本 (用于编译)
- Apple Silicon (M1/M2/M3) 或 Intel Mac

## 编译方法

### 1. 克隆仓库

```bash
git clone git@github.com:yxyyds666/macOS-EDL-Tools.git
cd macOS-EDL-Tools
```

### 2. 安装依赖

```bash
# 安装 libusb
brew install libusb
```

### 3. 使用 Xcode 编译

```bash
# 打开项目
open EDLTool.xcodeproj

# 或使用命令行编译
xcodebuild -project EDLTool.xcodeproj -scheme EDLTool -configuration Release
```

### 4. 编译完成后

编译后的应用位于 `build/Release/EDLTool.app`，可复制到 Applications 目录。

## 使用方法

### 进入 EDL 模式

**方法一：硬件组合键**
1. 关机状态下，同时按住 音量上 + 音量下
2. 连接 USB 数据线到电脑
3. 等待设备进入 9008 模式

**方法二：ADB 命令**
```bash
adb reboot edl
```

**方法三：Fastboot 命令 (部分设备)**
```bash
fastboot oem edl
```

### 发送引导加载器

1. 启动 EDL Tool
2. 将设备进入 EDL 模式并连接
3. 应用会自动检测到设备
4. 选择对应的引导加载器文件 (.elf/.mbn/.melf)
5. 点击"发送"按钮

## 项目结构

```
macOS-EDL-Tools/
├── EDLTool/                    # 主应用代码
│   ├── Views/                  # SwiftUI 视图
│   ├── ViewModels/             # 视图模型
│   ├── Services/               # 服务层
│   │   ├── EDLService.swift    # EDL 命令执行
│   │   ├── USBMonitor.swift    # USB 设备监控
│   │   └── PartitionManager.swift
│   ├── Models/                 # 数据模型
│   └── Utils/                  # 工具类
├── Resources/                  # 资源文件
│   ├── edl_bin                 # EDL 工具二进制
│   ├── fh_loader               # Firehose 加载器
│   ├── bootloaders/            # 引导加载器文件
│   └── oplus-9008/             # OPPO/一加专用文件
└── Frameworks/                 # 嵌入的框架
    └── libusb-1.0.0.dylib      # libusb 动态库
```

## 技术实现

- **USB 设备检测**: 使用 IOKit 框架监控 USB 设备连接
- **EDL 通信**: 通过 libusb 与 9008 设备通信
- **Sahara/Firehose 协议**: 实现高通 EDL 协议栈

## 注意事项

1. 请确保使用高质量 USB 数据线
2. 部分设备可能需要授权操作
3. OPPO/一加设备需要 VIP 认证 (开发中)
4. 操作有风险，请提前备份数据

## 致谢

- [bkerler/edl](https://github.com/bkerler/edl) - EDL Python 工具
- [libusb](https://libusb.info/) - 跨平台 USB 库
- [fh_loader](https://github.com/LonelyFool/fh_loader) - Firehose 加载器

## 许可证

MIT License

## 免责声明

本工具仅供学习和研究目的。使用本工具造成的任何设备损坏或数据丢失，作者不承担任何责任。请在充分了解风险的情况下使用。
