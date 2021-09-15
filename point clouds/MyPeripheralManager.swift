//
//  MyPeripheralManager.swift
//  MyPeripheralManager
//
//  Created by Nick Franczak on 9/14/21.
//

import Foundation
import CoreBluetooth

class MyPeripheralManager: NSObject, CBPeripheralManagerDelegate{
    static let shared = MyPeripheralManager()
    var peripheralManager: CBPeripheralManager = CBPeripheralManager()
    
    let serviceUUID: CBUUID = CBUUID(string: "00008101000E2D4E2190801E")
    let characteristicUUID: CBUUID = CBUUID(string: "00008101000E2D4E2190801E")
    let advertisementDataLocalNameKey : String = "max8Chars"
    
    func start() {
        if !peripheralManager.isAdvertising{
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch self.peripheralManager.state {
        case .poweredOn:
            print("peripheral powered on")
            
            let _: CBMutableService = CBMutableService(type: serviceUUID, primary: true)
            
            let _: CBMutableCharacteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
            
        case .poweredOff:
            print("peripheral powered off")
        case .resetting:
            print("peripheral resetting")
        case .unauthorized:
            print("peripheral unauthorized")
        case .unknown:
            print("peripheral unknown")
        case .unsupported:
            print("peripheral unsupported")
        @unknown default:
            print("peripheral unknown")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        
        peripheral.delegate = self
        
        if !self.peripheralManager.isAdvertising {
            self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID], CBAdvertisementDataLocalNameKey: advertisementDataLocalNameKey])
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        var arr: [UInt8] = [0,0,0,0,0] // example data
        let value: Data = Data(bytes: &arr, count: arr.count)
        request.value = value
        self.peripheralManager.respond(to: request, withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        if let request = requests.first {
            if let value = request.value {
                let valueBytes: [UInt8] = [UInt8](value)
                print("received data: \(valueBytes)")
            }
        }
    }
}
