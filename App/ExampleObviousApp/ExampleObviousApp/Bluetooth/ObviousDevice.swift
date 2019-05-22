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
    
    public weak var delegate: ObviousDeviceDelegate?
    
    private var featureManager: OcelotFeatureManager!
    private var firmwareManager: OcelotFirmwareManager!
    private var deviceConnector: OcelotDeviceConnector!
    private var featureList: [OcelotFeatureInfo] = []
    private var serviceInfo: [CBUUID: [CBUUID]] = [:]
    private var discoveredServices: Set<String> = Set<String>()
    private var discoveredServicesCounter: Int = 0
    private var characteristicDict: [String: CBCharacteristic] = [:]
    private var serialNumber: String?
    private var featureCount: Int = 0
    private var fwUpgradeInProgress: Bool = false
    
    private(set) var peripheral: CBPeripheral!
    
    init(peripheral: CBPeripheral) {
        super.init()
        self.peripheral = peripheral
        self.peripheral.delegate = self
        setupObvious()
    }
    
    private func setupObvious() {
        featureManager = OcelotFeatureManager.getDemoFeatureManager()
        featureManager.setFeatureEventListener(self)
        featureManager.setAPIKey(OCELOTPRODUCTIDENTIFIER.EXAMPLE_API_KEY)
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        firmwareManager = OcelotFirmwareManager.getDemoFirmwareManager()
        firmwareManager.setEventListener(self)
        firmwareManager.setAPIKey(OCELOTPRODUCTIDENTIFIER.EXAMPLE_API_KEY)
        if let serviceCharMap = deviceConnector.getServerInformation() {
            serviceInfo = serviceCharMap
        }
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
    
    public func startFirmareCheckAndFeatureUpdate() {
        deviceConnector = firmwareManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        firmwareManager.upgradeCheck(ObviousDevice.BOILERPLATE_APP_VER, self)
    }
    
    public func resetFeatures() {
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        featureManager.startFeatureReset()
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
                startFirmareCheckAndFeatureUpdate()
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

extension ObviousDevice: OcelotFeatureEventListener {
    func onFeatureUpdateStatus(_ status: Int) {
        if status == FeatureUpdateConstants.SUCCESS {
            featureManager.getFeatureList()
            serialNumber = featureManager.getSerialNumber()
            delegate?.didUpdateSerialNumber(serialNumber: serialNumber)
            
        }
        delegate?.didUpdateFeatureUpdateStatus(status: status)
        
        // Below contains the feature update statuses that may be called back
        // from didUpdateFeatureUpdateStatus
        switch status {
        case FeatureUpdateConstants.SUCCESS:
            debugPrint("Feature update: Success")
            break
        case FeatureUpdateConstants.CLEAR_SUCCESS:
            debugPrint("Feature update: Clear Features Success")
            break
        case FeatureUpdateConstants.SUCCESS_RESETTING:
            debugPrint("Feature update: Resetting")
            break
        case FeatureUpdateConstants.NOT_PROVISIONED:
            debugPrint("Device is not provisioned")
            break
        case FeatureUpdateConstants.RESET_COMPLETE:
            debugPrint("Feature update: Reset complete")
            break
        case FeatureUpdateConstants.DOWNLOAD_FAILED:
            debugPrint("Feature file download failed")
            break
        case FeatureUpdateConstants.WRITE_FAILED:
            debugPrint("Feature file write failed")
            break
        case FeatureUpdateConstants.CLEAR_FAILED:
            debugPrint("Feature clear failed")
            break
        case FeatureUpdateConstants.FAILED:
            debugPrint("Feature Update failed")
            break
        case FeatureUpdateConstants.TIMEOUT:
            debugPrint("Timeout occured during feature update process")
            break
        default:
            debugPrint("\(#function) Status update: \(status)")
            break
        }
    }
    
    func onProvisioningStatus(_ status: Int) {
        debugPrint("onProvisioningStatus  \(status)")
        
        // Below contains the provisioning statuses that may be called back
        // from onProvisioningStatus
        switch status {
        case ProvisionUpdateConstants.SUCCESS:
            debugPrint("Provisioning: Success")
            break
        case ProvisionUpdateConstants.START:
            debugPrint("Provisioning: Starting")
        case ProvisionUpdateConstants.DOWNLOAD_FAILED:
            debugPrint("Provision file download failed")
            break
        case ProvisionUpdateConstants.WRITE_FAILED:
            debugPrint("Provision file write failed")
            break
        case ProvisionUpdateConstants.FAILED:
            debugPrint("Provisioning failure")
            break
        case ProvisionUpdateConstants.TIMEOUT:
            debugPrint("Timeout occured during provisioning process")
        default:
            debugPrint("\(#function) Status update: \(status)")
            break
        }
    }
    
    func onCheckFeatureStatus(_ featureid: Int, _ status: Int) {
        debugPrint("\(#function) - featureid: \(featureid) status: \(status)")
        if let index = featureList.firstIndex(where: { feature in feature.id == featureid }) {
            featureList[index].active = (status == 1)
        } else {
            debugPrint("\(#function) - Error: featureid: \(featureid) not found.")
        }
        checkFeatureListStatus()
    }
    
    func onFeatureList(_ features: [String : Int]?) {
        debugPrint("\(#function) - Feature List obtained: \(String(describing: features))")
        if let list = features {
            featureList = []
            for (feature, id) in list {
                featureList.append(OcelotFeatureInfo(id: id, name: feature, active: false))
            }
        }
        checkFeatureListStatus()
    }
    
    private func checkFeatureListStatus() {
        if featureCount < featureList.count {
            let id = featureList[featureCount].id
            featureManager.checkFeatureStatus(featureid: id)
            featureCount += 1
        } else {
            delegate?.didFinishFeatureListStatusCheck(featureList: featureList)
            featureCount = 0
        }
    }
    
}

extension ObviousDevice: OcelotFirmwareEventListener {
    func onFirmwareProgressUpdate(_ serialNumber: String, _ percent: Int) {
        delegate?.didUpdateFirmwareProgress(serialNumber: serialNumber, percent: percent)
    }
    
    func onFirmwareUpgradeStatus(_ status: OcelotFirmwareManager.OcelotFirmwareUpgradeStatus) {
        fwUpgradeInProgress = false
        if status == .SUCCESS {
            delegate?.didFirmwareUpgradeSuccess()
        } else {
            delegate?.didFirmwareUpgradeFail()
        }
        
        // Below contains the firmware upgrade statuses that may be called back
        // from onFirmwareUpgradeStatus
        switch status {
        case .SUCCESS:
            debugPrint("Firmware Upgrade: Success")
            break
        case .DOWNLOAD_FAILED:
            debugPrint("Firmware file download failed")
            break
        case .FAILED:
            debugPrint("Firmware upgrade failure")
            break
        case .BOND_CANCELLED:
            debugPrint("Bonding request was cancelled")
            break
        case .UNAVAILABLE:
            debugPrint("Firmware upgrades not available on device")
            break
        }
    }
}

extension ObviousDevice: OcelotFirmwareAvailableListener {
    func onFirmwareUpgradeAvailable(currentVersion: Int64, newFirmwareInfo: OcelotFirmwareInfo?) {
        // currentVersion: The firmware version on the connected device.
        // Check if the version code is equal to the constant, OcelotServiceConstants.INVALID_FIRMWARE_VERSION.
        // If it is equal, then the firmware version is invalid and cannot be read. Else, the format of the
        // version code is as follows, starting from the most significant digit:
        //                    XXX,    XXX,    XXX
        //                  (major).(minor).(patch)
        // where X represents each digit in the Int64 value.
        delegate?.didCheckFirmware(currentVersion: currentVersion == OcelotServiceConstants.INVALID_FIRMWARE_VERSION ? "unknown" : "\(String(format: "%d", ((currentVersion / 1000000) % 1000))).\(String(format: "%d", ((currentVersion / 1000) % 1000))).\(String(format: "%d", (currentVersion % 1000)) )", updateAvailable: newFirmwareInfo != nil)
        startFeatureUpdate()
    }
}
