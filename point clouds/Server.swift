//
//  server.swift
//  server
//
//  Created by Nick Franczak on 10/12/21.
//


import Foundation
import Swifter
import OSLog


class Server {
    var renderer: Renderer!
    var host = ""
    var port = 0
    var on = false
    let server = HttpServer()
    let encoder = JSONEncoder()
    // The rate at which the server will send new measurement values on measurementStream.
    var refreshRateHz:Int
    // wasOn records whether or not the server wasOn when the app was backgrounded.
    var wasOn = false
    
    init() {
        self.port = 3000
        self.refreshRateHz = 50
        initHandlers()
        os_log("initialized server")
        start()

    }
    
    // Turn server off when the app enters the background.
    func enteredBackground() {
        self.server.stop()
    }
    
    // Turn server back on when the app enters the foreground if it wasOn when it was backgrounded.
    func enteredForeground() {
        start()
    }
    
    func initHandlers() {
        server["/hello"] = { request in
            os_log("1")
            return HttpResponse.ok(.text("hello!"))
        }
        server["/measurement"] = { request in
            if let meas = self.renderer.serverpointcloud() {
            //if let meas = self.getLatestMeasurement() {
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
            os_log("4")
            return HttpResponse.raw(200, "OK", nil, { writer in
                var meas:Data?
                var start = Date().millisecondsSince1970
                var end = Date().millisecondsSince1970
                // Writes stream of measurement data at refreshRateHz.
                while self.on {
                    try autoreleasepool {
                        start = Date().millisecondsSince1970
                        meas = self.renderer.serverpointcloud()
                        //meas = self.getLatestMeasurement()
                        if meas != nil {
                            try writer.write(meas!)
                            try writer.write(newLine!)
                        } else {
                            print("failed to get latest measurement")
                        }
                        end = Date().millisecondsSince1970
                        usleep(useconds_t(max(0, (Int64(1000/self.refreshRateHz) - (end-start))*Int64(ms))))
                    }
                }
            })
        }
    }
    
    // Starts server on self.port.
    func start() {
        do {
            // Default priority is background, which significantly impacts the performance of usleep. See
            // https://stackoverflow.com/questions/49620284/bad-precision-of-usleep-when-is-executed-in-background-thread-in-swift
            try self.server.start(UInt16(self.port), priority: DispatchQoS.QoSClass.userInteractive)
            os_log("server started")
            self.on = true
            if let addr = getWiFiAddress() {
                print(addr)
                self.host = addr
            } else {
                self.host = "No WiFi address"
            }
        } catch {
            print("failed to start server")
        }
    }
    
    // Stops server.
    func stop() {
        self.server.stop()
        self.host = ""
        self.on = false
    }
    
    // Return IP address of WiFi interface (en0) as a String
    func getWiFiAddress() -> String? {
        var address : String?

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
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
                if  name == "en0" {

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

