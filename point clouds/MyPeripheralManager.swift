//
//  MyPeripheralManager.swift
//  MyPeripheralManager
//
//  Created by Nick Franczak on 9/14/21.
//
import Foundation
import CoreBluetooth
import UIKit

class MyPeripheralManager: NSObject, CBPeripheralManagerDelegate{
    static let shared = MyPeripheralManager()
    

    var peripheralManager: CBPeripheralManager = CBPeripheralManager()

    var serviceUUID: CBUUID = CBUUID()
    var characteristicUUID: CBUUID = CBUUID()
    let advertisementDataLocalNameKey : String = "max8Chars"

    func start() {
        print("1")
        let deviceUUID: String = UIDevice.current.identifierForVendor!.uuidString
        serviceUUID = CBUUID(string: deviceUUID)
        characteristicUUID = CBUUID(string: deviceUUID)
        if !peripheralManager.isAdvertising{
            print("2")
            print(CBAdvertisementDataIsConnectable)
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }

    }
    // before 3 is printed we get this message: [CoreBluetooth] XPC connection invalid
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch self.peripheralManager.state {
        case .poweredOn:
            print("3")
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

    func peripheralManager(_ peripheral: CBPeripheralManager) {
        print("4")
        peripheral.delegate = self

        if !self.peripheralManager.isAdvertising {
            self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID], CBAdvertisementDataLocalNameKey: advertisementDataLocalNameKey])
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("5")
        var arr: [UInt8] = [0,0,0,0,0] // example data
        let value: Data = Data(bytes: &arr, count: arr.count)
        request.value = value
        self.peripheralManager.respond(to: request, withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("6")
        if let request = requests.first {
            if let value = request.value {
                let valueBytes: [UInt8] = [UInt8](value)
                print("received data: \(valueBytes)")
            }
        }
    }
}
