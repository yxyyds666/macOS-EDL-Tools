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
    
    // Qualcomm EDL device identifiers
    static let qualcommVID = 0x05C6
    static let edlPIDs: [Int] = [0x9008, 0x900E, 0x901D, 0x9025]
    
    // MARK: - Start Monitoring
    func startMonitoring() {
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
    
    // MARK: - Stop Monitoring
    func stopMonitoring() {
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
        
        let vendorID = properties[kUSBVendorID] as? Int ?? 0
        let productID = properties[kUSBProductID] as? Int ?? 0
        let locationID = properties[kUSBDevicePropertyLocationID] as? Int ?? 0
        
        let name = properties[kUSBProductString] as? String ?? "Unknown Device"
        let serialNumber = properties[kUSBSerialNumberString] as? String
        let manufacturer = properties[kUSBVendorString] as? String
        
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
        
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        
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
        
        return allDevices
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
