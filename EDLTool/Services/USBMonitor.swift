import Foundation
import IOKit
import IOKit.usb

// MARK: - USB Monitor Service
class USBMonitor: ObservableObject {
    @Published var devices: [USBDevice] = []
    @Published var connectedDevice: USBDevice?
    @Published var isMonitoring = false
    
    private var runLoopSource: CFRunLoopSource?
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private var pollingTimer: Timer?
    
    // Qualcomm EDL device identifiers
    static let qualcommVID = 0x05C6
    static let edlPIDs: [Int] = [0x9008, 0x900E, 0x901D, 0x9025]
    
    // MARK: - Start Monitoring
    func startMonitoring() {
        // 首先主动扫描现有设备
        scanExistingDevices()
        
        // 启动定时轮询（每 2 秒检查一次设备状态）
        startPolling()
        
        guard !isMonitoring else { return }
        
        // Create notification port
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notificationPort else {
            print("Failed to create IONotificationPort")
            return
        }
        
        runLoopSource = IONotificationPortGetRunLoopSource(port).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        // Set up matching notification for USB devices
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        
        // Match Qualcomm EDL devices
        matchingDict[kUSBVendorID] = Self.qualcommVID
        
        // Add callbacks for device arrival and removal
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // Device matched callback
        let matchResult = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matchingDict,
            { (refCon, iterator) in
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
                monitor.deviceAdded(iterator: iterator)
            },
            selfPointer,
            &matchedIterator
        )
        
        if matchResult == kIOReturnSuccess {
            // Process existing devices
            deviceAdded(iterator: matchedIterator)
        }
        
        // Device terminated callback
        let terminationResult = IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            matchingDict,
            { (refCon, iterator) in
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
                monitor.deviceRemoved(iterator: iterator)
            },
            selfPointer,
            &terminatedIterator
        )
        
        if terminationResult == kIOReturnSuccess {
            // Process removed devices
            deviceRemoved(iterator: terminatedIterator)
        }
        
        isMonitoring = true
    }
    
    // MARK: - Start Polling
    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollDeviceStatus()
        }
    }
    
    // MARK: - Poll Device Status
    private func pollDeviceStatus() {
        let allDevices = scanAllDevices()
        let currentEDLDevice = allDevices.first { $0.isEDLMode }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 更新设备列表
            self.devices = allDevices
            
            // 检查 EDL 设备状态变化
            if let edlDevice = currentEDLDevice {
                // 发现 EDL 设备
                if self.connectedDevice?.id != edlDevice.id {
                    self.connectedDevice = edlDevice
                    print("EDL device connected: \(edlDevice.name)")
                }
            } else {
                // EDL 设备已断开
                if self.connectedDevice != nil {
                    self.connectedDevice = nil
                    print("EDL device disconnected")
                }
            }
        }
    }
    
    // MARK: - Scan Existing Devices
    private func scanExistingDevices() {
        let allDevices = scanAllDevices()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for device in allDevices {
                if !self.devices.contains(device) {
                    self.devices.append(device)
                }
                
                if device.isEDLMode {
                    self.connectedDevice = device
                    print("Found EDL device: \(device.name) VID:\(String(format: "%04X", device.vendorID)) PID:\(String(format: "%04X", device.productID))")
                }
            }
        }
    }
    
    // MARK: - Stop Monitoring
    func stopMonitoring() {
        // 停止定时器
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        guard isMonitoring else { return }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        
        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
            matchedIterator = 0
        }
        
        if terminatedIterator != 0 {
            IOObjectRelease(terminatedIterator)
            terminatedIterator = 0
        }
        
        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
        
        isMonitoring = false
    }
    
    // MARK: - Device Added Callback
    private func deviceAdded(iterator: io_iterator_t) {
        var device: io_object_t = 0
        
        while true {
            device = IOIteratorNext(iterator)
            if device == 0 { break }
            
            defer { IOObjectRelease(device) }
            
            let usbDevice = createUSBDevice(from: device)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let newDevice = usbDevice, !self.devices.contains(newDevice) {
                    self.devices.append(newDevice)
                    
                    // Auto-select EDL device
                    if newDevice.isEDLMode {
                        self.connectedDevice = newDevice
                    }
                }
            }
        }
    }
    
    // MARK: - Device Removed Callback
    private func deviceRemoved(iterator: io_iterator_t) {
        var device: io_object_t = 0
        
        while true {
            device = IOIteratorNext(iterator)
            if device == 0 { break }
            
            defer { IOObjectRelease(device) }
            
            let usbDevice = createUSBDevice(from: device)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let removedDevice = usbDevice {
                    self.devices.removeAll { $0.id == removedDevice.id }
                    
                    if self.connectedDevice?.id == removedDevice.id {
                        self.connectedDevice = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Create USB Device from IOKit
    private func createUSBDevice(from ioDevice: io_object_t) -> USBDevice? {
        guard let properties = getDeviceProperties(ioDevice) else { return nil }
        
        // 支持新旧两种属性名
        let vendorID = properties[kUSBVendorID] as? Int 
            ?? properties["idVendor"] as? Int 
            ?? 0
        let productID = properties[kUSBProductID] as? Int 
            ?? properties["idProduct"] as? Int 
            ?? 0
        let locationID = properties[kUSBDevicePropertyLocationID] as? Int 
            ?? properties["locationID"] as? Int 
            ?? 0
        
        let name = properties[kUSBProductString] as? String 
            ?? properties["Product"] as? String 
            ?? properties["USB Product Name"] as? String
            ?? properties["IORegistryEntryName"] as? String
            ?? "Unknown Device"
        
        let serialNumber = properties[kUSBSerialNumberString] as? String
            ?? properties["Serial Number"] as? String
            ?? properties["USB Serial Number"] as? String
        
        let manufacturer = properties[kUSBVendorString] as? String
            ?? properties["Manufacturer"] as? String
            ?? properties["USB Vendor Name"] as? String
        
        return USBDevice(
            id: "\(vendorID)-\(productID)-\(locationID)",
            name: name,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber,
            locationID: locationID,
            manufacturer: manufacturer
        )
    }
    
    // MARK: - Get Device Properties
    private func getDeviceProperties(_ device: io_object_t) -> [String: Any]? {
        var properties: [String: Any] = [:]
        
        // Get device name
        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameResult = IORegistryEntryGetName(device, &nameBuffer)
        if nameResult == KERN_SUCCESS {
            properties["IORegistryEntryName"] = String(cString: nameBuffer)
        }
        
        // Get all properties
        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            device,
            &unmanagedProperties,
            kCFAllocatorDefault,
            0
        )
        
        if result == KERN_SUCCESS, let props = unmanagedProperties?.takeRetainedValue() {
            if let dict = props as? [String: Any] {
                properties.merge(dict) { (_, new) in new }
            }
        }
        
        return properties.isEmpty ? nil : properties
    }
    
    // MARK: - Scan All USB Devices
    func scanAllDevices() -> [USBDevice] {
        var allDevices: [USBDevice] = []
        
        // 方法1: 传统 USB 设备
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        var iterator: io_iterator_t = 0
        var result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        
        if result == kIOReturnSuccess {
            var device: io_object_t = 0
            
            while true {
                device = IOIteratorNext(iterator)
                if device == 0 { break }
                defer { IOObjectRelease(device) }
                
                if let usbDevice = createUSBDevice(from: device) {
                    allDevices.append(usbDevice)
                }
            }
            IOObjectRelease(iterator)
        }
        
        // 方法2: IOUSBHostDevice (macOS 新架构)
        let hostMatching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        var hostIterator: io_iterator_t = 0
        result = IOServiceGetMatchingServices(kIOMainPortDefault, hostMatching, &hostIterator)
        
        if result == kIOReturnSuccess {
            var device: io_object_t = 0
            
            while true {
                device = IOIteratorNext(hostIterator)
                if device == 0 { break }
                defer { IOObjectRelease(device) }
                
                if let usbDevice = createUSBDeviceFromHostDevice(device) {
                    // 避免重复
                    if !allDevices.contains(where: { $0.id == usbDevice.id }) {
                        allDevices.append(usbDevice)
                    }
                }
            }
            IOObjectRelease(hostIterator)
        }
        
        return allDevices
    }
    
    // MARK: - Create USB Device from IOUSBHostDevice
    private func createUSBDeviceFromHostDevice(_ ioDevice: io_object_t) -> USBDevice? {
        guard let properties = getDeviceProperties(ioDevice) else { return nil }
        
        // 新架构使用 idVendor/idProduct (小写)
        let vendorID = properties["idVendor"] as? Int ?? 0
        let productID = properties["idProduct"] as? Int ?? 0
        let locationID = properties["locationID"] as? Int ?? 0
        
        // 产品名称可能在 "Product" 或 "USB Product Name"
        let name = properties["Product"] as? String 
            ?? properties["USB Product Name"] as? String
            ?? properties["IORegistryEntryName"] as? String
            ?? "Unknown Device"
        
        let serialNumber = properties["Serial Number"] as? String
            ?? properties["USB Serial Number"] as? String
        
        let manufacturer = properties["Manufacturer"] as? String
            ?? properties["USB Vendor Name"] as? String
        
        let device = USBDevice(
            id: "\(vendorID)-\(productID)-\(locationID)",
            name: name,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber,
            locationID: locationID,
            manufacturer: manufacturer
        )
        
        return device
    }
    
    // MARK: - Check for EDL Device
    func checkForEDLDevice() -> USBDevice? {
        let allDevices = scanAllDevices()
        return allDevices.first { $0.isEDLMode }
    }
}

// MARK: - Serial Port Helper
class SerialPortHelper {
    static func findEDLPorts() -> [String] {
        var ports: [String] = []
        
        let ttyPath = "/dev"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: ttyPath) else {
            return ports
        }
        
        for item in contents {
            // Look for Qualcomm serial ports (usually cu.usbmodem* or tty.usbmodem*)
            if item.hasPrefix("cu.usbmodem") || item.hasPrefix("tty.usbmodem") ||
               item.hasPrefix("cu.QCOMM") || item.hasPrefix("tty.QCOMM") {
                ports.append("\(ttyPath)/\(item)")
            }
        }
        
        return ports
    }
    
    static func getPreferredPort() -> String? {
        let ports = findEDLPorts()
        return ports.first
    }
}
