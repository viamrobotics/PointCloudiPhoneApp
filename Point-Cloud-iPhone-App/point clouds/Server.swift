//
//  server.swift
//  server
//
//  Created by Nick Franczak on 10/12/21.
//


import Foundation
import Swifter
import OSLog
import SwiftUI


// based off core/pointcloud/pointcloud.go
struct Measurement: Codable {
    // Size returns the number of points in the cloud.
    var Size: Int?

    // HasColor returns whether or not the cloud consists of points with color.
    var HasColor: Bool?

    // HasValue returns whether or not the cloud consists of points with user data value.
    var HasValue: Bool?

    // MinX returns the minimum x coordinate of all points in the cloud.
    var MinX: Float64?

    // MaxY returns the maximum y coordinate of all points in the cloud.
    var MaxX: Float64?

    // MinY returns the minimum y coordinate of all points in the cloud.
    var MinY: Float64?

    // MaxY returns the maximum y coordinate of all points in the cloud.
    var MaxY: Float64?

    // MinZ returns the minimum z coordinate of all points in the cloud.
    var MinZ: Float64?

    // MaxZ returns the maximum z coordinate of all points in the cloud.
    var MaxZ: Float64?
    
    // Point cloud data
    var poclo: Optional<Array<SIMD3<Float>>>?
    
    // RBG data
    var rbg: Optional<Array<SIMD3<Float>>>?
}

class Server {
    var renderer: Renderer!
    var host = ""
    var port: String{
        willSet{
            // When port changes, need to stop server if it is on
            if on {
                stop()
            }
        }
    }
    //var port = 0
    var on = false
    let server = HttpServer()
    let encoder = JSONEncoder()
    // The rate at which the server will send new measurement values on measurementStream.
    var refreshRateHz:Int
    
    init(refreshRateHz: Int, port: Int) {
        self.port = String(port)
        self.refreshRateHz = refreshRateHz
        initHandlers()
        //initObservers()
        os_log("Started server")
        start()
        
    }
        
    // Turn server off when the app enters the background.
    func enteredBackground() {
        stop()
    }
    
    // Turn server back on when the app enters the foreground if it wasOn when it was backgrounded.
    func enteredForeground() {
        start()
    }
    
    func initHandlers() {
        server["/hello"] = { _ in
            HttpResponse.ok(.text("hello!"))
        }
        server["/measurement"] = { _ in
            if let meas = self.getLatestMeasurement() {
                os_log("2")
                return HttpResponse.ok(.data(meas, contentType: "application/json"))
            } else {
                os_log("3")
                return HttpResponse.badRequest(.text("couldn't get latest measurement"))
            }
        }
        server["/measurementStream"] = { _ in
                    let newLine = "\n".data(using: .utf8)
                    let ms = 1000
                    return HttpResponse.raw(200, "OK", nil) { writer in
                        var meas: Data?
                        var start = Date().millisecondsSince1970
                        var end = Date().millisecondsSince1970
                        // Writes stream of measurement data at refreshRateHz.
                        while self.on {
                            try autoreleasepool {
                                start = Date().millisecondsSince1970
                                meas = self.getLatestMeasurement()
                                if meas != nil {
                                    try writer.write(meas!)
                                    try writer.write(newLine!)
                                } else {
                                    print("failed to get latest measurement")
                                }
                                end = Date().millisecondsSince1970
                                usleep(useconds_t(max(0, (Int64(1000 / self.refreshRateHz) - (end - start)) * Int64(ms))))
                            }
                        }
                    }
        }
    }
    
//    func initObservers() {
//        NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground), name: .enteredBackground, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground), name: .enteredForeground, object: nil)
//    }
    
    // Starts server on self.port.
    func start() {
        do {
            // Default priority is background, which significantly impacts the performance of usleep. See
            // https://stackoverflow.com/questions/49620284/bad-precision-of-usleep-when-is-executed-in-background-thread-in-swift
            try server.start(UInt16(Int(port)!), priority: DispatchQoS.QoSClass.userInteractive)
            on = true
            if let addr = getWiFiAddress() {
                os_log("Our IP address: \(addr)")
                host = addr
            } else {
                host = "No WiFi address"
            }
        } catch {
            print("failed to start server")
        }
    }
    
    // Stops server.
    func stop() {
        server.stop()
        host = ""
        on = false
        os_log("server off")
    }
    
    func getLatestMeasurement() -> Data? {
        var rawMeas = Measurement()
        rawMeas.poclo = renderer.r3points()
        do {
            let data = try encoder.encode(rawMeas)
            return data
        } catch {
            return nil
        }
    }
    
    // Return IP address of WiFi interface (en0) as a String
    func getWiFiAddress() -> String? {
        var address: String?

        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
}


extension Date {
 var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds:Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
}