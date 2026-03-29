#!/usr/bin/env python3
"""
USB to Serial Bridge for Qualcomm EDL on macOS
Creates a pseudo-terminal that bridges to EDL device via libusb

Usage:
    python3 usb_serial_bridge.py
    # Then use fh_loader with the printed port, e.g.:
    # fh_loader --port=/dev/ttys003 --signeddigests=...
"""

import usb.core
import usb.util
import os
import pty
import select
import sys
import threading
import time

# Qualcomm EDL IDs
VID = 0x05C6
PID = 0x9008

def find_edl_device():
    """Find Qualcomm EDL device"""
    dev = usb.core.find(idVendor=VID, idProduct=PID)
    return dev

def main():
    print("=" * 60)
    print("USB-Serial Bridge for Qualcomm EDL (macOS)")
    print("=" * 60)
    
    # Find EDL device
    dev = find_edl_device()
    if dev is None:
        print("ERROR: EDL device not found (VID:05c6 PID:9008)")
        print("Please put device in EDL mode first.")
        return 1
    
    print(f"[+] Found EDL device")
    
    # Detach kernel driver if active
    for cfg in dev:
        for intf in cfg:
            if dev.is_kernel_driver_active(intf.bInterfaceNumber):
                dev.detach_kernel_driver(intf.bInterfaceNumber)
                print(f"[+] Detached kernel driver from interface {intf.bInterfaceNumber}")
    
    # Set configuration
    dev.set_configuration()
    cfg = dev.get_active_configuration()
    intf = cfg[(0, 0)]
    
    # Find endpoints
    ep_out = usb.util.find_descriptor(intf, custom_match=lambda e: 
        usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_OUT)
    ep_in = usb.util.find_descriptor(intf, custom_match=lambda e: 
        usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_IN)
    
    if ep_out is None or ep_in is None:
        print("ERROR: Could not find endpoints")
        return 1
    
    print(f"[+] Endpoints: OUT=0x{ep_out.bEndpointAddress:02x}, IN=0x{ep_in.bEndpointAddress:02x}")
    
    # Create pseudo-terminal pair
    master_fd, slave_fd = pty.openpty()
    slave_name = os.ttyname(slave_fd)
    
    print(f"[+] Created pseudo-terminal: {slave_name}")
    print("")
    print(f"*** Now run fh_loader with --port={slave_name} ***")
    print("")
    print("Example:")
    print(f"  fh_loader --port={slave_name} --signeddigests=digest.bin --sendimage=loader.melf")
    print("")
    print("Press Ctrl+C to stop the bridge...")
    print("-" * 60)
    
    # Bridge loop
    usb_buffer = bytearray()
    running = True
    
    def usb_reader():
        """Read from USB and buffer"""
        nonlocal usb_buffer, running
        while running:
            try:
                data = ep_in.read(0x4000, timeout=100)
                if data:
                    usb_buffer.extend(data)
            except usb.core.USBError as e:
                if e.errno != 110:  # Not timeout
                    print(f"USB read error: {e}")
            except:
                pass
    
    # Start USB reader thread
    reader_thread = threading.Thread(target=usb_reader, daemon=True)
    reader_thread.start()
    
    try:
        while True:
            # Check for data from master (fh_loader)
            rlist, _, _ = select.select([master_fd], [], [], 0.1)
            
            if master_fd in rlist:
                try:
                    data = os.read(master_fd, 0x4000)
                    if data:
                        # Send to USB
                        ep_out.write(data)
                except OSError:
                    break
            
            # Send USB buffer to master (fh_loader)
            if usb_buffer:
                try:
                    os.write(master_fd, bytes(usb_buffer))
                    usb_buffer.clear()
                except OSError:
                    break
                    
    except KeyboardInterrupt:
        print("\n[*] Bridge stopped by user")
    finally:
        running = False
        os.close(master_fd)
        os.close(slave_fd)
        usb.util.dispose_resources(dev)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
