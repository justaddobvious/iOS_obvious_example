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

class DeviceViewController: UIViewController {
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var serialLabel: UILabel!
    @IBOutlet weak var firmwareVersionLabel: UILabel!
    @IBOutlet weak var firmwareButton: UIButton!
    @IBOutlet weak var featureList: UITableView!
    
    public var currentDevice: ObviousDevice?
    private var features: [OcelotFeatureInfo] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        BluetoothInteractor.shared.delegate = self
        currentDevice?.delegate = self
        featureList.delegate = self
        featureList.dataSource = self
        deviceNameLabel.text = currentDevice?.peripheral.name ?? "unknown device name"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if StateManager.shared.purchaseMade {
            currentDevice?.startFirmareCheckAndFeatureUpdate()
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
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        currentDevice?.resetFeatures()
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
        return features.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "featureCell", for: indexPath)
        
        let feature = features[indexPath.row]
        cell.textLabel?.text = feature.name
        cell.detailTextLabel?.text = feature.active ? "enabled" : "disabled"
        return cell
    }
    
    
}

extension DeviceViewController: ObviousDeviceDelegate {
    func didCheckFirmware(currentVersion: String, updateAvailable: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.firmwareButton.isUserInteractionEnabled = updateAvailable
            self?.firmwareVersionLabel.text = "firmware version: " + currentVersion
        }
    }
    
    func didUpdateFirmwareProgress(serialNumber: String, percent: Int) {
        // MARK: Firmware upgrade progress is updated from the following callback
    }
    
    func didFirmwareUpgradeSuccess() {
        // MARK: Handle firmware upgrade success callbacks here
    }
    
    func didFirmwareUpgradeFail() {
        // MARK: Handle firmware upgrade failure callbacks here
    }
    
    func didUpdateFeatureUpdateStatus(status: Int) {
        // MARK: Handle feauture update state callbacks here
    }
    
    func didUpdateProvisionStatus(status: Int) {
        // MARK: Handle provisioning state callbacks here
    }
    
    func didUpdateSerialNumber(serialNumber: String?) {
        StateManager.shared.currentSerialNumber = serialNumber
        DispatchQueue.main.async { [weak self] in
            self?.serialLabel.text = serialNumber
        }
        
    }
    
    func didFinishFeatureListStatusCheck(featureList: [OcelotFeatureInfo]) {
        DispatchQueue.main.async { [weak self] in
            self?.features = featureList
            self?.featureList.reloadData()
        }
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
