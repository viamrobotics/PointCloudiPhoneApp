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

extension MTKView : RenderDestinationProvider {
}

//class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate{
    
    var session: ARSession!
    var renderer: Renderer!
//    var centralManager: CBCentralManager!
//    var myPeripheral: CBPeripheral!
        

    
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
        //centralManager = CBCentralManager(delegate: self, queue: nil)
        MyPeripheralManager.shared.start()
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
    
    
    //MARK: - BlueTooth
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        if central.state == CBManagerState.poweredOn {
//            print("BLE on")
//            central.scanForPeripherals(withServices: nil, options: nil)
//        }
//        else {
//            print("Something wrongw BLE")
//        }
//    }
//
//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        //print(peripheral.name ?? "default value")
//        if let pname = peripheral.name {
//            if pname == "nick-pi" {
//                print(peripheral.name!)
//                self.centralManager.stopScan()
//
//                self.myPeripheral = peripheral
//                self.myPeripheral.delegate = self
//                self.centralManager.connect(peripheral, options: nil)
//                print(peripheral)
//            }
//        }
//    }
//
//    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        self.myPeripheral.discoverServices(nil)
//    }
}
    
  

    // MARK: - ARSessionDelegate
    
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        // Present an error message to the user
//
//    }
//
//    func sessionWasInterrupted(_ session: ARSession) {
//        // Inform the user that the session has been interrupted, for example, by presenting an overlay
//
//    }
//
//    func sessionInterruptionEnded(_ session: ARSession) {
//        // Reset tracking and/or remove existing anchors if consistent tracking is required
//
//    }

