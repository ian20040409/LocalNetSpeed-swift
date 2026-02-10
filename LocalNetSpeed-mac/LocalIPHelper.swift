import Foundation
import Network

struct LocalIPHelper {
    static func getLocalIPAddress() async -> String {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                var result = "無法取得"
                for interface in path.availableInterfaces {
                    if interface.type == .wifi || interface.type == .wiredEthernet {
                        if let ip = getIPAddress(for: interface) {
                            result = ip
                            break
                        }
                    }
                }
                if result == "無法取得" {
                    result = getIPAddressTraditional()
                }
                monitor.cancel()
                continuation.resume(returning: result)
            }
            let queue = DispatchQueue(label: "NetworkMonitor")
            monitor.start(queue: queue)
        }
    }
    
    private static func getIPAddress(for interface: NWInterface) -> String? {
        // Network.framework 介面資訊較難直接取得 IP，這裡回到傳統方法 (if applicable)
        return nil
    }
    
    private static func getIPAddressTraditional() -> String {
        var address: String = "無法取得"
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    // Common interface names on macOS: en0 (WiFi), en1/en2 (Ethernet), bridge0
                    if name == "en0" || name == "en1" || name.hasPrefix("en") && !name.contains("lo") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let addr = interface?.ifa_addr
                        if getnameinfo(addr, socklen_t((addr?.pointee.sa_len)!),
                                      &hostname, socklen_t(hostname.count),
                                      nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
