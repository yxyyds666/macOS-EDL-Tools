import Foundation
import Combine

// MARK: - Device View Model
class DeviceViewModel: ObservableObject {
    @Published var connectedDevice: USBDevice?
    @Published var availableDevices: [USBDevice] = []
    @Published var isMonitoring = false
    @Published var lastScanTime: Date?
    @Published var errorMessage: String?
    
    private let usbMonitor = USBMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false
    
    // MARK: - Start Monitoring
    func startMonitoring() {
        // 防止重复启动
        guard !hasStarted else {
            // 已经启动，只刷新设备列表
            refreshDevices()
            return
        }
        hasStarted = true
        
        usbMonitor.startMonitoring()
        isMonitoring = true
        
        // Subscribe to USB monitor updates
        usbMonitor.$devices
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableDevices)
        
        usbMonitor.$connectedDevice
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectedDevice)
        
        usbMonitor.$isMonitoring
            .receive(on: DispatchQueue.main)
            .assign(to: &$isMonitoring)
        
        // Initial scan
        refreshDevices()
    }
    
    // MARK: - Stop Monitoring
    func stopMonitoring() {
        usbMonitor.stopMonitoring()
        isMonitoring = false
    }
    
    // MARK: - Refresh Devices
    func refreshDevices() {
        let devices = usbMonitor.scanAllDevices()
        availableDevices = devices
        lastScanTime = Date()
        
        // Auto-select EDL device
        if let edlDevice = devices.first(where: { $0.isEDLMode }) {
            connectedDevice = edlDevice
        }
    }
    
    // MARK: - Select Device
    func selectDevice(_ device: USBDevice) {
        connectedDevice = device
    }
    
    // MARK: - Get Device Info
    func getDeviceInfo() -> String {
        guard let device = connectedDevice else {
            return "未连接设备"
        }
        
        return """
        设备名称: \(device.name)
        厂商ID: 0x\(String(format: "%04X", device.vendorID))
        产品ID: 0x\(String(format: "%04X", device.productID))
        序列号: \(device.serialNumber ?? "N/A")
        制造商: \(device.manufacturer ?? "N/A")
        EDL模式: \(device.isEDLMode ? "是" : "否")
        """
    }
}
