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
import ObviousAPI

class ObviousDevice: NSObject {
    
    private static let BOILERPLATE_APP_VER: String = "1.0.0"
    
    private var featureManager: OcelotFeatureManager!
    private var firmwareManager: OcelotFirmwareManager!
    private var deviceConnector: OcelotDeviceConnector!
    private var serviceInfo: [CBUUID: [CBUUID]] = [:]
    private var discoveredServices: Set<String> = Set<String>()
    private var discoveredServicesCounter: Int = 0
    private var characteristicDict: [String: CBCharacteristic] = [:]
    private var serialNumber: String?
    private var fwUpgradeInProgress: Bool = false
    private var fwAvailableListener: OcelotFirmwareAvailableListener?
    
    private(set) var peripheral: CBPeripheral!
    
    init(peripheral: CBPeripheral) {
        super.init()
        self.peripheral = peripheral
        self.peripheral.delegate = self
        setupObvious()
    }
    
    private func setupObvious() {
        featureManager = OcelotFeatureManager.getDemoFeatureManager()
        featureManager.setAPIKey(OCELOTPRODUCTIDENTIFIER.EXAMPLE_API_KEY)
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        firmwareManager = OcelotFirmwareManager.getDemoFirmwareManager()
        firmwareManager.setAPIKey(OCELOTPRODUCTIDENTIFIER.EXAMPLE_API_KEY)
        if let serviceCharMap = deviceConnector.getServerInformation() {
            serviceInfo = serviceCharMap
        }
    }
    
    public func setListeners(_ featureListener: OcelotFeatureEventListener,
                             _ toggleListener: OcelotToggleEventListener,
                             _ firmwareEventListener: OcelotFirmwareEventListener,
                             _ firmwareAvailableListener: OcelotFirmwareAvailableListener) {
        featureManager.setFeatureEventListener(featureListener)
        featureManager.setToggleEventListener(toggleListener)
        firmwareManager.setEventListener(firmwareEventListener)
        fwAvailableListener = firmwareAvailableListener
    }
    
    public func startFeatureUpdate() {
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        featureManager.startFeatureUpdate()
    }
    
    public func startFirmwareUpgrade() {
        fwUpgradeInProgress = true
        deviceConnector = firmwareManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        firmwareManager.startFirmwareUpgrade(ObviousDevice.BOILERPLATE_APP_VER)
    }
    
    public func didFinishFirmwareUpgrade() {
        fwUpgradeInProgress = false
    }
    
    public func getFeatureList() {
        featureManager.getFeatureList()
    }
    
    public func checkFeatureStatus(featureId: Int) {
        featureManager.checkFeatureStatus(featureid: featureId)
    }
    
    public func getSerial() -> String? {
        return featureManager.getSerialNumber()
    }
    
    public func startFirmwareCheck(_ listener: OcelotFirmwareAvailableListener) {
        deviceConnector = firmwareManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        firmwareManager.upgradeCheck(ObviousDevice.BOILERPLATE_APP_VER, listener)
    }
    
    public func resetFeatures() {
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        featureManager.startFeatureReset()
    }
    
    public func toggleFeature(id: Int) {
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        featureManager.toggleFeature(featureid: id)
    }
    
    
}

extension ObviousDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            discoveredServices = Set(services.map { service in service.uuid.uuidString })
            for service in services {
                if let characteristicUUIDs = serviceInfo[service.uuid] {
                    peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                characteristicDict[characteristic.uuid.uuidString] = characteristic
                self.peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        if discoveredServices.contains(service.uuid.uuidString) {
            discoveredServicesCounter += 1
        }
        if discoveredServicesCounter == discoveredServices.count {
            if !fwUpgradeInProgress {
                if let listener = fwAvailableListener {
                    startFirmwareCheck(listener)
                }
            }
            discoveredServicesCounter = 0
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristicDict[characteristic.uuid.uuidString] != nil {
            if let data = characteristic.value {
                deviceConnector.onUpdateDeviceData(characteristic.uuid.uuidString, [UInt8](data))
            }
            if let err = error as NSError? {
                deviceConnector.onReadStatus(characteristic.uuid.uuidString, UInt8(err.code))
            }
        } else {
            debugPrint("\(#function) - Error: unhandled update to char value for peripheral: \(String(describing: peripheral)) with characteristic: \(characteristic)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let status: UInt8 = error == nil ? OcelotServiceConstants.WRITE_DATA_SUCCESS : OcelotServiceConstants.WRITE_DATA_FAILURE
        deviceConnector.onWriteStatus(characteristic.uuid.uuidString, status)
    }
    
    func handleConnectionState(_ state: Int) {
        if state == OcelotDeviceConnector.CONNECTION_STATE_CONNECTED {
            peripheral.discoverServices(Array(serviceInfo.keys))
        }
        featureManager.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
        firmwareManager.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
        deviceConnector.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
    }
}

extension ObviousDevice: OcelotDeviceConnectorCallback {
    func requestCharacteristicWrite(serviceId: String, characteristicId: String, rawdata: [UInt8]) -> Bool {
        guard let characteristic = characteristicDict[characteristicId] else { return false }
        peripheral.writeValue(Data(rawdata), for: characteristic, type: .withResponse)
        return true
    }
    
    func requestCharacteristicWriteWithoutResponse(serviceId: String, characteristicId: String, rawdata: [UInt8]) -> Bool {
        guard let characteristic = characteristicDict[characteristicId] else { return false }
        peripheral.writeValue(Data(rawdata), for: characteristic, type: .withoutResponse)
        return true
    }
    
    func requestCharacteristicRead(serviceId: String, characteristicId: String) -> Bool {
        guard let characteristic = characteristicDict[characteristicId] else { return false }
        peripheral.readValue(for: characteristic)
        return true
    }
    
    func requestDeviceConnect() {
        BluetoothInteractor.shared.connectToDevice(by: peripheral.identifier)
    }
    
    func requestDeviceDisconnect() {
        BluetoothInteractor.shared.disconnectCurrentDevice()
    }
    
    func getOcelotProductIdentifier() -> String? {
        return OCELOTPRODUCTIDENTIFIER.EXAMPLE_MANUFACTURER_PRODUCT_ID
    }
    
}
