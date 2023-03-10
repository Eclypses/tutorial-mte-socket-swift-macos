//
// ****************************************************************
// SocketLabs/Common
// GeneralHelpers.swift created on 3/23/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import Foundation

func setBytesToBigEndian(_ bytes: [UInt8]) -> [UInt8] {
	var byteArray = bytes
	// Set byteOrder to BigEndian if it's not
	if CFByteOrderGetCurrent() == CFByteOrderLittleEndian.rawValue {
		byteArray.reverse()
	}
	return byteArray
}

func setBytesBackToLittleEndian(_ bytes: [UInt8]) -> [UInt8] {
	var byteArray = bytes
	// Set byteOrder to BigEndian if it's not
	if CFByteOrderGetCurrent() == CFByteOrderLittleEndian.rawValue {
		byteArray.reverse()
	}
	return byteArray
}

func getipv4Addresses() -> [String] {
	var addresses = [String]()

	// Get list of all interfaces on the local machine:
	var ifaddr : UnsafeMutablePointer<ifaddrs>?
	guard getifaddrs(&ifaddr) == 0 else { return [] }
	guard let firstAddr = ifaddr else { return [] }

	// For each interface ...
	for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
		let flags = Int32(ptr.pointee.ifa_flags)
		let addr = ptr.pointee.ifa_addr.pointee

		// Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
		if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
			if addr.sa_family == UInt8(AF_INET) {
//				addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) // replace above for both ipv4 and ipv6 addresses
				// Convert interface address to a human readable string:
				var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
				if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
								nil, socklen_t(0), NI_NUMERICHOST) == 0) {
					let address = String(cString: hostname)
					addresses.append(address)
				}
			}
		}
	}

	freeifaddrs(ifaddr)
	return addresses
}
