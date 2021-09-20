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
import CoreLocation

extension MTKView : RenderDestinationProvider {
}
class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate, CBPeripheralManagerDelegate{
    var session: ARSession!
    var renderer: Renderer!

    var peripheralManager: CBPeripheralManager!
    
    // static UUID
    var serviceUUID: CBUUID = CBUUID(string: "0846BFB3-6A8C-48AC-88F5-06D3E8681068")
    var characteristicUUID: CBUUID = CBUUID(string: "0846BFB3-6A8C-48AC-88F5-06D3E8681068")
    let advertisementDataLocalNameKey : String = "LiDAR Phone"


    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
        session = ARSession()
        session.delegate = self

        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self

            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }

            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: view.device!, renderDestination: view)

            renderer.drawRectResized(size: view.bounds.size)
        }

        // Do any additional setup after loading the view.
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

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

    //MARK: - Peripheral BlueTooth
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("peripheral on")
            let mutableservice : CBMutableService = CBMutableService(type: serviceUUID, primary: true)
            let mutableCharacteristic : CBMutableCharacteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.write, .read], value: nil, permissions: [CBAttributePermissions.writeable, CBAttributePermissions.readable])
            mutableservice.characteristics = [mutableCharacteristic]
            peripheral.add(mutableservice)
            print(mutableservice)
            peripheral.startAdvertising([CBAdvertisementDataLocalNameKey: advertisementDataLocalNameKey])
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
         if let error = error {
            print("Add service failed: \(error.localizedDescription)")
            return
        }
        print("Add service succeeded")

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Start advertising failed: \(error.localizedDescription)")
            return
        }
        print("Start advertising succeeded")
    }


    }
}



    









// MARK: - v1
//class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate, CBPeripheralManagerDelegate{
//    var session: ARSession!
//    var renderer: Renderer!
//
//    var peripheralManager: CBPeripheralManager!
//    var serviceUUID: CBUUID = CBUUID()
//    var characteristicUUID: CBUUID = CBUUID()
//    let advertisementDataLocalNameKey : String = "LiDAR Phone"
//
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        // Set the view's delegate
//        session = ARSession()
//        session.delegate = self
//
//        // Set the view to use the default device
//        if let view = self.view as? MTKView {
//            view.device = MTLCreateSystemDefaultDevice()
//            view.backgroundColor = UIColor.clear
//            view.delegate = self
//
//            guard view.device != nil else {
//                print("Metal is not supported on this device")
//                return
//            }
//
//            // Configure the renderer to draw to the view
//            renderer = Renderer(session: session, metalDevice: view.device!, renderDestination: view)
//
//            renderer.drawRectResized(size: view.bounds.size)
//        }
//
//        // Do any additional setup after loading the view.
//        let deviceUUID: String = UIDevice.current.identifierForVendor!.uuidString
//        serviceUUID = CBUUID(string: deviceUUID)
//        characteristicUUID = CBUUID(string: deviceUUID)
//        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
//
//    }
//
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        // Create a session configuration
//        let configuration = ARWorldTrackingConfiguration()
//
//        // Run the view's session
//        session.run(configuration)
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//
//        // Pause the view's session
//        session.pause()
//    }
//
//    // MARK: - MTKViewDelegate
//
//    // Called whenever view changes orientation or layout is changed
//    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
//        renderer.drawRectResized(size: size)
//    }
//
//    // Called whenever the view needs to render
//    func draw(in view: MTKView) {
//        renderer.update()
//    }
//
//    //MARK: - Peripheral BlueTooth
//    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
//        if peripheral.state == .poweredOn {
//            print("peripheral on")
//            let mutableservice : CBMutableService = CBMutableService(type: serviceUUID, primary: true)
//            let mutableCharacteristic : CBMutableCharacteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.write, .read], value: nil, permissions: [CBAttributePermissions.writeable, CBAttributePermissions.readable])
//            mutableservice.characteristics = [mutableCharacteristic]
//            peripheral.add(mutableservice)
//            peripheral.startAdvertising([CBAdvertisementDataLocalNameKey: advertisementDataLocalNameKey])
//        }
//    }
//
//    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
//         if let error = error {
//            print("Add service failed: \(error.localizedDescription)")
//            return
//        }
//        print("Add service succeeded")
//
//    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
//        if let error = error {
//            print("Start advertising failed: \(error.localizedDescription)")
//            return
//        }
//        print("Start advertising succeeded")
//    }
//
//
//    }
//}
