//
//  ViewController.swift
//  point clouds
//
//  Created by Nick Franczak on 9/10/21.
//

import UIKit
import Metal
import MetalKit
import ARKit
import CoreBluetooth
import OSLog

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate{
    // for ARKIT
    var session: ARSession!
    var renderer: Renderer!
    var HTTPserver: Server!

    // for bluetooth
    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic?
    let serviceUUID: CBUUID = CBUUID(string: "D6F60427-BF2D-4208-ADEB-267697102667")
    let characteristicUUID: CBUUID = CBUUID(string: "D6F60427-BF2D-4208-ADEB-267697102667")
    let CBAdvertisementDataIsConnectable: String = "1"
    let advertisementDataLocalNameKey : String = "LiDAR Phone"
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    var connectedCentral: CBCentral?


    override func viewDidLoad() {
        
        //start server
        let _ = Server(refreshRateHz: 50, port: 3000)
        
        
        //instantiate peripheralManager
        //peripheralManager = CBPeripheralManager(delegate: self, queue: nil)

        super.viewDidLoad()

        //os_log("CBPeriphalManager instantiated")

        // Set the view's delegate
        session = ARSession()
        session.delegate = self

        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self

            guard view.device != nil else {
                os_log("metal is not supported on this device")
                return
            }

            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: view.device!, renderDestination: view)
            renderer.drawRectResized(size: view.bounds.size)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Don't keep advertising going while we're not showing.
        //peripheralManager.stopAdvertising()
        
        //stop the server
        self.HTTPserver.stop()

        super.viewWillDisappear(animated)
        os_log("stopped advertising")

        // Pause the view's session
        session.pause()
        

    }

    // MARK: - MTKViewDelegate
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }

    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.update()
    }

    // MARK: - Private funcs for Bluetooth
    // sending data when appropriate
    static var sendingEOM = false

    private func sendData() {

        guard let transferCharacteristic = transferCharacteristic else {
            return
        }

        // First up, check if we're meant to be sending an EOM
        if ViewController.sendingEOM {
            // send it
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            // Did it send?
            if didSend {
                // It did, so mark it as sent
                ViewController.sendingEOM = false
                os_log("sent: EOM")
            }
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }

        // We're not sending an EOM, so we're sending data
        // Is there any left to send?
        if sendDataIndex >= dataToSend.count {
            // No data left.  Do nothing
            return
        }

        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        while didSend {

            // Work out how big it should be
            var amountToSend = dataToSend.count - sendDataIndex
            if let mtu = connectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }

            // Copy out the data we want
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))

            // Send it
            didSend = peripheralManager.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)

            // If it didn't work, drop out and wait for the callback
            if !didSend {
                return
            }

            let stringFromData = String(data: chunk, encoding: .utf8)
            os_log("sent %d bytes: %s", chunk.count, String(describing: stringFromData))

            // It did send, so update our index
            sendDataIndex += amountToSend
            // Was it the last one?
            if sendDataIndex >= dataToSend.count {
                // It was - send an EOM

                // Set this so if the send fails, we'll send it next time
                ViewController.sendingEOM = true

                //Send it
                let eomSent = peripheralManager.updateValue("EOM".data(using: .utf8)!,
                                                             for: transferCharacteristic, onSubscribedCentrals: nil)

                if eomSent {
                    // It sent; we're all done
                    ViewController.sendingEOM = false
                    os_log("sent: EOM")
                }
                return
            }
        }
    }

    // setting up out initial services and characteristics to broadcast
    private func setupPeripheral(){

        //build our service

        // CBMutableCharacteristic instantiation
        let transferCharacteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.notify, .writeWithoutResponse], value: nil, permissions: [.readable, .writeable])

        // create service from characteristic
        let transferService = CBMutableService(type: serviceUUID, primary: true)

        // add characteristic to service
        transferService.characteristics = [transferCharacteristic]

        // add it to the peripheral manager
        peripheralManager.add(transferService)

        // save the characteristic for later
        self.transferCharacteristic = transferCharacteristic

    }

    // start advertising our presence
    // iphone should show up on RPI as 'LiDAR Phone pc'
    private func startad(){
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
                                            CBAdvertisementDataLocalNameKey: advertisementDataLocalNameKey])
        os_log("bool if advertising is working: \(self.peripheralManager.isAdvertising)")
    }
}
// MARK: - Extensions
extension ViewController: CBPeripheralManagerDelegate{
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            os_log("peripheral is on")
            setupPeripheral()
            os_log("setup done")
        }
        if peripheral.state == .poweredOff {
            peripheral.stopAdvertising()
            os_log("peripheral is off")
        }
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
         if let error = error {
             os_log("add service failed: \(error.localizedDescription)")
            return
        }
        os_log("add service succeeded")
        startad()
        os_log("starting to advertise")
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            os_log("start advertising failed: \(error.localizedDescription)")
            return
        }
        os_log("Start advertising succeeded")
        os_log("bool if advertising is working: \(self.peripheralManager.isAdvertising)")
        print(renderer.pointcloud())
        
    }
    
    // MARK: - sending data over BLE
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("central subscribed to characteristic: \(characteristic)")
        // Get the data
        dataToSend = renderer.pointcloud()
        // ~ 15K+ bytes

        // Reset the index
        sendDataIndex = 0

        // save central
        connectedCentral = central

        // Start sending
        sendData()
    }
    

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("central unsubscribed from characteristic")
        connectedCentral = nil
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager){
        os_log("local peripheral is ready to send data to subscribers")
        // Start sending again
        // check that this is ok and that full pc's are going through to the RPI
        dataToSend = renderer.pointcloud()
        sendData()
    }
}
