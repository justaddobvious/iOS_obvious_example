//////////////////////////////////////////////////////////////////////////
// Copyright © 2019,
// 4iiii Innovations Inc.,
// Cochrane, Alberta, Canada.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are not permitted without express written approval of
// 4iiii Innovations Inc.
///////////////////////////////////////////////////////////////////////

import Foundation
import CoreBluetooth

class BluetoothInteractor: NSObject {
    
    public static let shared: BluetoothInteractor = BluetoothInteractor()
    
    private var manager: CBCentralManager!
    public weak var delegate: BluetoothInteractorDelegate?
    private var currentObviousDevice: ObviousDevice?
    
    private override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    private var discoveredPeripherals: [UUID:CBPeripheral] = [:]
    
}

extension BluetoothInteractor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            delegate?.didManagerPowerOn()
        } else {
            debugPrint("Bluetooth not available.")
        }
    }
    
    public func startScan(forServices: [CBUUID]? = nil) {
        if manager.state == .poweredOn {
            manager.scanForPeripherals(withServices: forServices, options: nil)
        }
    }
    
    public func stopScan() {
        manager.stopScan()
    }
 
    public func connectToDevice(by uuid: UUID) {
        if let peripheral = discoveredPeripherals[uuid] {
            manager.connect(peripheral, options: nil)
        }
    }
    
    public func forgetAndDisconnectCurrentDevice() {
        if let tempDevice = currentObviousDevice {
            currentObviousDevice = nil
            manager.cancelPeripheralConnection(tempDevice.peripheral)
        }
    }
    
    public func disconnectCurrentDevice() {
        if let tempDevice = currentObviousDevice {
            manager.cancelPeripheralConnection(tempDevice.peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name != "" {
            debugPrint("Discovered Device \(peripheral)")
            discoveredPeripherals[peripheral.identifier] = peripheral
            delegate?.didDiscoverPeripheral(info: DeviceInfo(name: name, uuid: peripheral.identifier))
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if currentObviousDevice == nil {
            currentObviousDevice = ObviousDevice(peripheral: peripheral)
        }
        delegate?.didConnectTo(currentObviousDevice!)
        currentObviousDevice?.handleConnectionState(peripheral.state.rawValue)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let device = currentObviousDevice {
            delegate?.didDisconnectFrom(device)
            currentObviousDevice?.handleConnectionState(peripheral.state.rawValue)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        currentObviousDevice = nil
        delegate?.didFailToConnect()
    }
    
}
