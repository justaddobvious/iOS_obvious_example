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

class DeviceViewController: ObviousViewController {
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var serialLabel: UILabel!
    @IBOutlet weak var featuresAvailableLabel: UILabel!
    @IBOutlet weak var firmwareVersionLabel: UILabel!
    @IBOutlet weak var firmwareButton: UIButton!
    @IBOutlet weak var featureListView: UITableView!
    @IBOutlet weak var softDeviceVersion: UILabel!
    @IBOutlet weak var bootloaderVersion: UILabel!
    
    public var currentDevice: ObviousDevice?
    private var featureList: [ObviousFeatureInfo] = []
    private var featureIdIndexMap: [Int: Int] = [:]
    private var featureCount: Int = 0
    
    private var currFWVersion: String?
    private var newFWVersion: String?
    private var fwUpgradeInProgress: Bool = false
    
    private let synchronizingAlert: UIAlertController = UIAlertController(title: "Synchronizing...", message: nil, preferredStyle: .alert)
    
    //-------------- Alerts for device
    private lazy var firmwareUpdateProgressView: UIProgressView = UIProgressView(progressViewStyle: .default)
    private lazy var firmwareUpdateProgressAlert: UIAlertController = UIAlertController(title: "Firmware Updating...", message: nil, preferredStyle: .alert)
    private lazy var firmwareUpdateNotAvailable: UIAlertController = UIAlertController(title: "No Update Available", message: "Your firmware is up to date.", preferredStyle: .alert)
    private lazy var firmwareUpdateAvailable: UIAlertController = UIAlertController(title: "Firmware Update Available", message: "Version \(newFWVersion ?? "Unknown") is available. Do you want to update?", preferredStyle: .alert)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        BluetoothInteractor.shared.delegate = self
        featureListView.delegate = self
        featureListView.dataSource = self
        deviceNameLabel.text = currentDevice?.peripheral.name ?? "Unknown Device Name"
        
    
        currentDevice?.setDeviceInfoDelegate(delegate: self)
        
        firmwareUpdateProgressView.frame = CGRect(x: 10, y: 70, width: 250, height: 0)
        firmwareUpdateProgressAlert.view.addSubview(firmwareUpdateProgressView)
        
        firmwareUpdateNotAvailable.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        firmwareUpdateAvailable.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(action:UIAlertAction) in
            self.present(self.firmwareUpdateProgressAlert, animated: true, completion: self.currentDevice?.startFirmwareUpgrade)
        }))
        firmwareUpdateAvailable.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(synchronizingAlert, animated: true, completion: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if StateManager.shared.purchaseMade {
            currentDevice?.startFeatureUpdate()
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
        firmwareUpdateProgressView.progress = 0.0
        currentDevice?.startFirmwareCheck(self)
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
        }
        
        // MARK: Handle feauture update state callbacks here
        if status != FeatureUpdateConstants.CLEAR_SUCCESS &&
            status != FeatureUpdateConstants.SUCCESS_RESETTING &&
            status != FeatureUpdateConstants.NOT_PROVISIONED &&
            status != FeatureUpdateConstants.RESET_COMPLETE {
            DispatchQueue.main.async { [weak self] in
                self?.synchronizingAlert.dismiss(animated: true, completion: { [weak self] () -> () in
                    let featureUpdateCompleteAlert = UIAlertController(title: "Feature Update Complete", message: status == FeatureUpdateConstants.SUCCESS ? "Features updated successfully!" : "Feature update failed! Status Code: \(status)", preferredStyle: .alert)
                    featureUpdateCompleteAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    self?.present(featureUpdateCompleteAlert, animated: true, completion: nil)
                })
            }
        }
        
        // MARK: Below contains the feature update statuses that may be called back.
        switch status {
        case FeatureUpdateConstants.SUCCESS:
            print("Feature update: Success")
            break
        case FeatureUpdateConstants.CLEAR_SUCCESS:
            print("Feature update: Clear Features Success")
            break
        case FeatureUpdateConstants.SUCCESS_RESETTING:
            print("Feature update: Resetting")
            break
        case FeatureUpdateConstants.NOT_PROVISIONED:
            print("Device is not provisioned")
            break
        case FeatureUpdateConstants.RESET_COMPLETE:
            print("Feature update: Reset complete")
            break
        case FeatureUpdateConstants.DOWNLOAD_FAILED:
            print("Feature file download failed")
            break
        case FeatureUpdateConstants.WRITE_FAILED:
            print("Feature file write failed")
            break
        case FeatureUpdateConstants.CLEAR_FAILED:
            print("Feature clear failed")
            break
        case FeatureUpdateConstants.FAILED:
            print("Feature Update failed")
            break
        case FeatureUpdateConstants.TIMEOUT:
            print("Timeout occured during feature update process")
            break
        default:
            print("\(#function) Status update: \(status)")
            break
        }
    }
    
    func onProvisioningStatus(_ status: Int) {
        print("onProvisioningStatus  \(status)")
        
        // MARK: Below contains the provisioning statuses that may be called back from onProvisioningStatus.
        switch status {
        case ProvisionUpdateConstants.SUCCESS:
            print("Provisioning: Success")
            break
        case ProvisionUpdateConstants.START:
            print("Provisioning: Starting")
        case ProvisionUpdateConstants.DOWNLOAD_FAILED:
            print("Provision file download failed")
            break
        case ProvisionUpdateConstants.WRITE_FAILED:
            print("Provision file write failed")
            break
        case ProvisionUpdateConstants.FAILED:
            print("Provisioning failure")
            break
        case ProvisionUpdateConstants.TIMEOUT:
            print("Timeout occured during provisioning process")
        default:
            print("\(#function) Status update: \(status)")
            break
        }
    }
    
    func onCheckFeatureStatus(_ featureid: Int, _ status: Int) {
        // MARK: This callback was called for checking the statuses of features prior to Obvious Version 1.3. Please use the onCheckFeatureStatus(_:_:) from the OcelotToggleEventListener protocol.
    }
    
    func onFeatureList(_ features: [String : Int]?) {
        print("\(#function) - Feature List obtained: \(String(describing: features))")
        if let list = features {
            featureList = []
            for (feature, id) in list {
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
                self?.featuresAvailableLabel.text = "Features Available: \(self?.featureList.count ?? 0)"
                self?.featureListView.reloadData()
            }
        }
    }
    
}

extension DeviceViewController: OcelotToggleEventListener {
    func onCheckFeatureStatus(_ featureId: Int, _ status: OcelotFeatureStatus) {
        print("\(#function) - featureid: \(featureId) status: \(status)")
        if let index = featureIdIndexMap[featureId] {
            featureList[index].status = status
        } else {
            print("\(#function) - Error: featureid: \(featureId) not found. Should not get here.")
        }
        checkFeatureListStatus()
    }
    
    func onCheckFeatureStatuses(_ featureStatuses: [Int : OcelotFeatureStatus]) {
        // MARK: If the OcelotFeatureManager method checkFeatureStatuses(featureIds:) is called to check feature statuses, handle the resulting feature statuses callback here.
    }
    
    func didToggleFeatureStatus(_ featureId: Int, _ status: OcelotFeatureStatus) {
        guard let index = featureIdIndexMap[featureId] else { return }
        DispatchQueue.main.async { [weak self] in
            self?.featureList[index].status = status
            self?.featureListView.reloadData()
        }
    }
    
    func didToggleFeatureStatuses(_ featureStatuses: [Int : OcelotFeatureStatus]) {
        // MARK: If the OcelotFeatureManager method setToggleStatuses(featureToggleStatuses:) is called to set the toggle statuses of certain feature statuses, handle the resulting feature statuses callback here.
    }
    
    func featureStatusFailure() {
        // MARK: Handle feature status checking and toggling event failures here.
    }
}

extension DeviceViewController: OcelotDeviceInfoDelegate {
    func onDeviceInfoAvailable(_ deviceInfo: OcelotDeviceInfo?) {
        // MARK: Handle device meta info callback here
        print(deviceInfo ?? "Device Info Nil!")
        StateManager.shared.currentSerialNumber = deviceInfo?.serialNumber ?? "Unknown"
        DispatchQueue.main.async { [weak self] in
            if deviceInfo == nil {
                self?.synchronizingAlert.dismiss(animated: true, completion: { [weak self] () -> () in
                    let featureUpdateCompleteAlert = UIAlertController(title: "Feature Update Complete", message: "Feature update failed!", preferredStyle: .alert)
                    featureUpdateCompleteAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    self?.present(featureUpdateCompleteAlert, animated: true, completion: nil)
                })
            }
            self?.serialLabel.text = deviceInfo?.serialNumber
            self?.currFWVersion = deviceInfo?.firmwareVersion
            self?.firmwareVersionLabel.text =  deviceInfo?.firmwareVersion ?? "Unknown"
            self?.softDeviceVersion.text = deviceInfo?.softDeviceVersion ?? "unknown"
            self?.bootloaderVersion.text = deviceInfo?.bootLoaderVersion ?? "Unknown"
            self?.currentDevice?.startFeatureUpdate()
        }
    }
}

extension DeviceViewController: OcelotFirmwareEventListener {
    func onFirmwareProgressUpdate(_ serialNumber: String, _ percent: Int) {
        // MARK: Firmware upgrade progress is updated from the following callback
        // MARK: Feed this percent into my object (progress bar)
        firmwareUpdateProgressView.progress = Float(percent)/100
        print("Firwamre progress is: \(percent)%")
    }
    
    func onFirmwareUpgradeStatus(_ status: OcelotFirmwareManager.OcelotFirmwareUpgradeStatus) {
        fwUpgradeInProgress = false
        currentDevice?.didFinishFirmwareUpgrade()
        
        DispatchQueue.main.async {  [weak self] in
            print("Firmware upgrade \(status == .SUCCESS ? "successful" : "unsuccesful")")
            self?.firmwareVersionLabel.text = self?.newFWVersion
            let firmwareUpdateComplete: UIAlertController = UIAlertController(title: status == .SUCCESS ? "Upgrade Successful" : "Upgrade Failed", message: status == .SUCCESS ? "Sucessfully upgraded from \(self?.currFWVersion ?? "Unknown") to \(self?.newFWVersion ?? "Unknown")!" : "Upgrade failed to complete.", preferredStyle: .alert)
            firmwareUpdateComplete.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self?.firmwareUpdateProgressAlert.dismiss(animated: true, completion: { () in self?.present(firmwareUpdateComplete, animated: true, completion: nil) })
        }
        
        // MARK: Below contains the firmware upgrade statuses that may be called back.
        switch status {
        case .SUCCESS:
            print("Firmware Upgrade: Success")
            break
        case .DOWNLOAD_FAILED:
            print("Firmware file download failed")
            break
        case .FAILED:
            print("Firmware upgrade failure")
            break
        case .BOND_CANCELLED:
            print("Bonding request was cancelled")
            break
        case .UNAVAILABLE:
            print("Firmware upgrades not available on device")
            break
        }
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
        
        if fwUpgradeInProgress && (newFirmwareInfo != nil) {
            currentDevice?.startFirmwareUpgrade()
        }
        
        DispatchQueue.main.async { [weak self] in
            if let self = self {
                if let info = newFirmwareInfo {
                    self.newFWVersion = "\(String(format: "%d", ((info.versionCode / 1000000) % 1000))).\(String(format: "%d", ((info.versionCode / 1000) % 1000))).\(String(format: "%d", (info.versionCode % 1000)) )"
                    self.firmwareUpdateAvailable.message = "Version \(self.newFWVersion ?? "Unknown") is available. Do you want to update?"
                    self.present(self.firmwareUpdateAvailable, animated: true, completion: nil)
                }
                else {
                    self.present(self.firmwareUpdateNotAvailable, animated: true)
                }
            }
            
        }
        
        
    }
}
