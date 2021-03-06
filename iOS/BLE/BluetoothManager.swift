//
//  BluetoothManager.swift
//  BLE
//
//  Credits to Leonardo Cardoso on 09/02/2017.
//  Implementation on developing by Hamilton Kamiya on 20200312
//  Copyright © 2017 leocardz.com. All rights reserved.
//

import Foundation
import CoreBluetooth
import UIKit

protocol BlueEar {

    func didStartConfiguration()

    func didStartAdvertising()

    func didSendData()
    func didReceiveData()

}

class BluetoothManager: NSObject {

    // MARK: - Properties
    let peripheralId: String = "62443cc7-15bc-4136-bf5d-0ad80c459215"
    let serviceUUID: String = "0cdbe648-eed0-11e6-bc64-92361f002671"
    let characteristicUUID: String = "199ab74c-eed0-11E6-BC64-92361F002672"

    let properties: CBCharacteristicProperties = [.read, .notify, .writeWithoutResponse, .write]
    let permissions: CBAttributePermissions = [.readable, .writeable]

    var blueEar: BlueEar?
    var peripheralManager: CBPeripheralManager?

    var serviceCBUUID: CBUUID?
    var characteristicCBUUID: CBUUID?

    var service: CBMutableService?

    var characterisctic: CBMutableCharacteristic?

    // MARK: - Initializers
    convenience init (delegate: BlueEar?) {

        self.init()

        self.blueEar = delegate

        guard
            let serviceUUID: UUID = NSUUID(uuidString: self.serviceUUID) as UUID?,
            let characteristicUUID: UUID = NSUUID(uuidString: self.characteristicUUID) as UUID?
            else { return }

        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        self.characteristicCBUUID = CBUUID(nsuuid: characteristicUUID)

        guard
            let serviceCBUUID: CBUUID = self.serviceCBUUID,
            let characteristicCBUUID: CBUUID = self.characteristicCBUUID
            else { return }

        self.service = CBMutableService(type: serviceCBUUID, primary: true)

        self.characterisctic = CBMutableCharacteristic(type: characteristicCBUUID, properties: self.properties, value: nil, permissions: self.permissions)

        let options: [String: Any] = [
            CBCentralManagerOptionRestoreIdentifierKey: self.peripheralId
        ]

        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: options)

        guard let characterisctic: CBCharacteristic = self.characterisctic else { return }

        self.service?.characteristics = [characterisctic]

        self.blueEar?.didStartConfiguration()

    }

    // MARK: - Functions
    func sendLocalNotification(text: String) {

        let notification: UILocalNotification = UILocalNotification()
        notification.alertTitle = "BLE"
        notification.alertBody = text

        UIApplication.shared.presentLocalNotificationNow(notification)

    }

}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        print("\nperipheralManagerDidUpdateState")

        if peripheral.state == .poweredOn {

            guard let service: CBMutableService = self.service else { return }

            self.peripheralManager?.removeAllServices()
            self.peripheralManager?.add(service)

        }

    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {

        print("\ndidAdd service")

        let advertisingData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [self.service?.uuid]
        ]
        self.peripheralManager?.stopAdvertising()
        self.peripheralManager?.startAdvertising(advertisingData)
        
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {

        print("\nperipheralManagerDidStartAdvertising")

        self.blueEar?.didStartAdvertising()
        
    }

    // Listen to dynamic values
    // Called when CBPeripheral .setNotifyValue(true, for: characteristic) is called
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {

        print("\ndidSubscribeTo characteristic")

        guard let characterisctic: CBMutableCharacteristic = self.characterisctic else { return }

        do {

            let dict: [String: String] = ["Hello": "Darkness"]
            let data: Data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)

            self.peripheralManager?.updateValue(data, for: characterisctic, onSubscribedCentrals: [central])

            self.blueEar?.didSendData()

        } catch let error {

            print(error)

        }
        
    }

    // Read static values
    // Called when CBPeripheral .readValue(for: characteristic) is called
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {

        print("\ndidReceiveRead request")

        if let uuid: CBUUID = self.characterisctic?.uuid, request.characteristic.uuid == uuid {

            print("Matching characteristic for reading")

        }

    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {

        print("\ndidReceiveWrite requests")

        guard let characteristicCBUUID: CBUUID = self.characteristicCBUUID else { return }

        for request: CBATTRequest in requests {

            if let value: Data = request.value, request.offset > value.count {

                print("Sending response: Error offset")

                self.peripheralManager?.respond(to: request, withResult: .invalidOffset)

            } else {

                print("Sending response: Success")
                self.peripheralManager?.respond(to: request, withResult: .success)

                if request.characteristic.uuid == characteristicCBUUID {

                    print("Matching characteristic for writing")

                    if let value: Data = request.value {

                        do {

                            let receivedData: [String: String] = try PropertyListSerialization.propertyList(from: value, options: [], format: nil) as! [String: String]

                            self.sendLocalNotification(text: "Value written by central is: \(receivedData)")

                            self.blueEar?.didReceiveData()

                        } catch let error {

                            print(error)

                        }

                    }

                }

            }

        }

    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        
        print("\ndidUnsubscribeFrom characteristic")
        
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {

        print("\nwillRestoreState")
        
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {

        print("\nperipheralManagerIsReady")
        
    }
    
}
