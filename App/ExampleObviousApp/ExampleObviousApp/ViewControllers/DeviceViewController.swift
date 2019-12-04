//////////////////////////////////////////////////////////////////////////
// Copyright © 2019,
// 4iiii Innovations Inc.,
// Cochrane, Alberta, Canada.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are not permitted without express written approval of
// 4iiii Innovations Inc.
///////////////////////////////////////////////////////////////////////

import UIKit
import ObviousAPI

class FeatureCell: UITableViewCell {
    
    fileprivate var toggleCallback: ((_ switch: UISwitch) -> ())?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var toggleSwitch: UISwitch!
    @IBAction func onToggleValueChanged(_ sender: UISwitch) {
        toggleCallback?(sender)
    }
    
}

class DeviceViewController: UIViewController {
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var serialLabel: UILabel!
    @IBOutlet weak var firmwareVersionLabel: UILabel!
    @IBOutlet weak var firmwareButton: UIButton!
    @IBOutlet weak var featureListView: UITableView!
    
    public var currentDevice: ObviousDevice?
    private var featureList: [ObviousFeatureInfo] = []
    private var featureIdIndexMap: [Int: Int] = [:]
    private var featureCount: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        BluetoothInteractor.shared.delegate = self
        featureListView.delegate = self
        featureListView.dataSource = self
        deviceNameLabel.text = currentDevice?.peripheral.name ?? "unknown device name"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if StateManager.shared.purchaseMade {
            currentDevice?.startFirmwareCheck(self)
            StateManager.shared.purchaseMade = false
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            BluetoothInteractor.shared.forgetAndDisconnectCurrentDevice()
            StateManager.shared.currentSerialNumber = nil
        }
    }
    
    @IBAction func firmwareButtonPressed(_ sender: Any) {
        currentDevice?.startFirmwareUpgrade()
    }
}

extension DeviceViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return featureList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "featureCell", for: indexPath) as! FeatureCell
        
        let feature = featureList[indexPath.row]
        cell.isUserInteractionEnabled = true
        cell.titleLabel.text = feature.name
        if feature.status == .Disabled {
            cell.statusLabel.text = "Locked"
        } else if feature.status == .Enabled(toggleState: .Deactivated) {
            cell.statusLabel.text = "Deactivated"
        } else if feature.status?.toggleState == .Activated {
            cell.statusLabel.text = "Activated"
        } else {
            cell.statusLabel.text = "Enabled"
        }
        cell.toggleSwitch.isHidden = feature.status?.toggleState != .Activated && feature.status?.toggleState != .Deactivated
        cell.toggleSwitch.setOn(feature.status == .Enabled(toggleState: .Activated), animated: false)
        cell.toggleCallback = { [weak self] (_) -> () in
            self?.featureListView.visibleCells.forEach { cell in
                cell.isUserInteractionEnabled = false
            }
            cell.statusLabel.text = "Toggling..."
            self?.currentDevice?.toggleFeature(id: feature.id)
            
        }
        return cell
    }
    
    
}

extension DeviceViewController: BluetoothInteractorDelegate {
    func didManagerPowerOn() {
        // not implemented
    }
    
    func didDiscoverPeripheral(info: DeviceInfo) {
        // not implemented
    }
    
    func didConnectTo(_ device: ObviousDevice) {
        // not implemented
    }
    
    func didDisconnectFrom(_ device: ObviousDevice) {
        // not implemented
    }
    
    func didFailToConnect() {
        self.navigationController?.popToRootViewController(animated: true)
    }
}

extension DeviceViewController: OcelotFeatureEventListener {
    func onFeatureUpdateStatus(_ status: Int) {
        if status == FeatureUpdateConstants.SUCCESS {
            currentDevice?.getFeatureList()
            StateManager.shared.currentSerialNumber = currentDevice?.getSerial()
            DispatchQueue.main.async { [weak self] in
                self?.serialLabel.text = StateManager.shared.currentSerialNumber
            }
            
        }
        
        // MARK: Below contains the feature update statuses that may be called back
        // from didUpdateFeatureUpdateStatus.
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
        
        // MARK: Below contains the provisioning statuses that may be called back
        // from onProvisioningStatus.
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
        // MARK: This callback was called for checking the statuses of features prior to Obvious Version
        // 1.3. Please use the onCheckFeatureStatus(_:_:) from the OcelotToggleEventListener protocol.
    }
    
    func onFeatureList(_ features: [String : Int]?) {
        debugPrint("\(#function) - Feature List obtained: \(String(describing: features))")
        if let list = features {
            featureList = []
            for (feature, id) in list {
                featureIdIndexMap[id] = featureList.count
                featureList.append(ObviousFeatureInfo(id: id, name: feature, status: nil))
            }
        }
        checkFeatureListStatus()
    }
    
    private func checkFeatureListStatus() {
        if featureCount < featureList.count {
            let id = featureList[featureCount].id
            featureCount += 1
            currentDevice?.checkFeatureStatus(featureId: id)
        } else {
            featureCount = 0
            DispatchQueue.main.async { [weak self] in
                self?.featureListView.reloadData()
            }
        }
    }
    
}

extension DeviceViewController: OcelotToggleEventListener {
    func onCheckFeatureStatus(_ featureId: Int, _ status: OcelotFeatureStatus) {
        debugPrint("\(#function) - featureid: \(featureId) status: \(status)")
        if let index = featureIdIndexMap[featureId] {
            featureList[index].status = status
        } else {
            debugPrint("\(#function) - Error: featureid: \(featureId) not found. Should not get here.")
        }
        checkFeatureListStatus()
    }
    
    func onCheckFeatureStatuses(_ featureStatuses: [Int : OcelotFeatureStatus]) {
        // MARK: If the OcelotFeatureManager method checkFeatureStatuses(featureIds:) is called to check
        // feature statuses, handle the resulting feature statuses callback here.
    }
    
    func didToggleFeatureStatus(_ featureId: Int, _ status: OcelotFeatureStatus) {
        guard let index = featureIdIndexMap[featureId] else { return }
        DispatchQueue.main.async { [weak self] in
            self?.featureList[index].status = status
            self?.featureListView.reloadData()
        }
    }
    
    func didToggleFeatureStatuses(_ featureStatuses: [Int : OcelotFeatureStatus]) {
        // MARK: If the OcelotFeatureManager method setToggleStatuses(featureToggleStatuses:) is called to
        // set the toggle statuses of certain feature statuses, handle the resulting feature statuses
        // callback here.
    }
    
    func featureStatusFailure() {
        // MARK: Handle feature status checking and toggling event failures here.
    }
}

extension DeviceViewController: OcelotFirmwareEventListener {
    func onFirmwareProgressUpdate(_ serialNumber: String, _ percent: Int) {
        // MARK: Firmware upgrade progress is updated from the following callback.
    }
    
    func onFirmwareUpgradeStatus(_ status: OcelotFirmwareManager.OcelotFirmwareUpgradeStatus) {
        currentDevice?.didFinishFirmwareUpgrade()
        
        // MARK: Handle firmware upgrade success and failure callbacks here.
        // Below contains the firmware upgrade statuses that may be called back
        // from onFirmwareUpgradeStatus.
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
        
        let alert = UIAlertController(title: "Firmware Upgrade", message: "Firmware upgrade \(status == .SUCCESS ? "was successful" : "failed")!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        
    }
}

extension DeviceViewController: OcelotFirmwareAvailableListener {
    func onFirmwareUpgradeAvailable(currentVersion: Int64, newFirmwareInfo: OcelotFirmwareInfo?) {
        // currentVersion: The firmware version on the connected device.
        // Check if the version code is equal to the constant, OcelotServiceConstants.INVALID_FIRMWARE_VERSION.
        // If it is equal, then the firmware version is invalid and cannot be read. Else, the format of the
        // version code is as follows, starting from the most significant digit:
        //                    XXX,    XXX,    XXX
        //                  (major).(minor).(patch)
        // where X represents each digit in the Int64 value.
        
        let ver = currentVersion == OcelotServiceConstants.INVALID_FIRMWARE_VERSION ? "unknown" : "\(String(format: "%d", ((currentVersion / 1000000) % 1000))).\(String(format: "%d", ((currentVersion / 1000) % 1000))).\(String(format: "%d", (currentVersion % 1000)) )"
        DispatchQueue.main.async { [weak self] in
            self?.firmwareVersionLabel.text = "firmware version: " + ver
        }
        currentDevice?.startFeatureUpdate()
    }
}
