#!/usr/bin/env python3
"""
VIP Authentication for OnePlus Chimera Loaders on macOS
Step 1: Send programmer via Sahara (using edl tool)
Step 2: Send signed digest via Firehose (using fh_loader via USB bridge)
"""

import usb.core
import usb.util
import os
import pty
import select
import sys
import subprocess
import time
import threading
import argparse

VID = 0x05C6
PID = 0x9008

def find_edl_device():
    """Find EDL device"""
    dev = usb.core.find(idVendor=VID, idProduct=PID)
    return dev

def setup_usb_device(dev):
    """Setup USB device for communication"""
    for cfg in dev:
        for intf in cfg:
            if dev.is_kernel_driver_active(intf.bInterfaceNumber):
                dev.detach_kernel_driver(intf.bInterfaceNumber)
    
    dev.set_configuration()
    cfg = dev.get_active_configuration()
    intf = cfg[(0, 0)]
    
    ep_out = usb.util.find_descriptor(intf, custom_match=lambda e: 
        usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_OUT)
    ep_in = usb.util.find_descriptor(intf, custom_match=lambda e: 
        usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_IN)
    
    return ep_out, ep_in

def create_usb_bridge(ep_out, ep_in):
    """Create USB to PTY bridge for fh_loader"""
    master_fd, slave_fd = pty.openpty()
    slave_name = os.ttyname(slave_fd)
    
    usb_buffer = bytearray()
    running = [True]
    
    def usb_reader():
        while running[0]:
            try:
                data = ep_in.read(0x4000, timeout=50)
                if data:
                    usb_buffer.extend(data)
            except:
                pass
    
    def bridge():
        while running[0]:
            try:
                rlist, _, _ = select.select([master_fd], [], [], 0.05)
                if master_fd in rlist:
                    data = os.read(master_fd, 0x4000)
                    if data:
                        ep_out.write(data)
                if usb_buffer:
                    os.write(master_fd, bytes(usb_buffer))
                    usb_buffer.clear()
            except:
                pass
    
    reader_thread = threading.Thread(target=usb_reader, daemon=True)
    bridge_thread = threading.Thread(target=bridge, daemon=True)
    reader_thread.start()
    bridge_thread.start()
    
    return master_fd, slave_fd, slave_name, running

EDL_BIN = "/Users/yuxi/vscode源码/macosOS-swfit-edltlool/Resources/edl_bin"

def send_programmer_via_edl(programmer_path, verbose=True):
    """Send programmer using edl tool (Sahara protocol)"""
    cmd = [EDL_BIN, f"--loader={programmer_path}", "--skipresponse"]
    if verbose:
        print(f"[+] Sending programmer via Sahara: {programmer_path}")
    
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    
    if verbose:
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)
    
    return result.returncode == 0

def send_vip_digest_via_bridge(slave_name, digest_path, programmer_path, verbose=True):
    """Send VIP digest via fh_loader through USB bridge"""
    cmd = [
        "/Users/yuxi/vscode源码/macosOS-swfit-edltlool/Resources/fh_loader",
        f"--port={slave_name}",
        f"--signeddigests={digest_path}",
        f"--sendimage={programmer_path}",  # Reference for digest verification
        "--noprompt",
        "--memoryname=ufs"
    ]
    
    if verbose:
        print(f"[+] Sending VIP digest via Firehose: {digest_path}")
    
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    
    if verbose:
        print(result.stdout)
        if result.stderr:
            print(result.stderr)
    
    return result.returncode == 0

def main():
    parser = argparse.ArgumentParser(description='VIP Authentication for OnePlus Chimera Loaders')
    parser.add_argument('--programmer', '-p', required=True, help='Path to programmer (.melf file)')
    parser.add_argument('--digest', '-d', required=True, help='Path to signed digest file')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    args = parser.parse_args()
    
    print("=" * 60)
    print("VIP Authentication for OnePlus Chimera Loaders")
    print("=" * 60)
    
    # Step 1: Find EDL device
    print("\n[1/4] Finding EDL device...")
    dev = find_edl_device()
    if dev is None:
        print("[-] EDL device not found!")
        sys.exit(1)
    print("[+] EDL device found!")
    
    # Step 2: Setup USB communication
    print("\n[2/4] Setting up USB communication...")
    ep_out, ep_in = setup_usb_device(dev)
    print("[+] USB endpoints configured")
    
    # Step 3: Send programmer via Sahara (edl tool)
    print("\n[3/4] Sending programmer via Sahara protocol...")
    if not send_programmer_via_edl(args.programmer, args.verbose):
        print("[-] Failed to send programmer!")
        sys.exit(1)
    print("[+] Programmer sent successfully!")
    
    # Step 4: Create USB bridge and send VIP digest
    print("\n[4/4] Sending VIP digest via Firehose protocol...")
    time.sleep(1)  # Wait for device to transition to Firehose mode
    
    # Re-setup USB after edl tool used it
    dev = find_edl_device()
    if dev is None:
        print("[-] Device disconnected after programmer send!")
        sys.exit(1)
    ep_out, ep_in = setup_usb_device(dev)
    
    master_fd, slave_fd, slave_name, running = create_usb_bridge(ep_out, ep_in)
    print(f"[+] PTY bridge created: {slave_name}")
    
    time.sleep(0.5)
    
    success = send_vip_digest_via_bridge(slave_name, args.digest, args.programmer, args.verbose)
    running[0] = False
    
    if success:
        print("\n" + "=" * 60)
        print("[+] VIP Authentication completed!")
        print("=" * 60)
    else:
        print("\n[-] VIP Authentication failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
