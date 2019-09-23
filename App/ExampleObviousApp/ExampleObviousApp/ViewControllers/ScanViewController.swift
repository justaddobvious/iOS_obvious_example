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

class ScanViewController: UITableViewController {
    
    private var discoveredDevices: [DeviceInfo] = []
    private let scanCellIdentifier: String = "scanCell"
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BluetoothInteractor.shared.delegate = self
        BluetoothInteractor.shared.startScan()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        BluetoothInteractor.shared.stopScan()
        discoveredDevices = []
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredDevices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: scanCellIdentifier, for: indexPath)
        
        let device = discoveredDevices[indexPath.row]
        cell.textLabel?.text = device.name
        cell.detailTextLabel?.text = device.uuid.uuidString
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        BluetoothInteractor.shared.connectToDevice(by: discoveredDevices[indexPath.row].uuid)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}

extension ScanViewController: BluetoothInteractorDelegate {
    func didManagerPowerOn() {
        BluetoothInteractor.shared.startScan()
    }
    
    func didDiscoverPeripheral(info: DeviceInfo) {
        guard !discoveredDevices.contains(where: { device in device.uuid == info.uuid }) else { return }
        discoveredDevices.append(info)
        tableView.reloadData()
    }
    
    func didConnectTo(_ device: ObviousDevice) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let newVC = storyboard.instantiateViewController(withIdentifier: "DeviceViewController") as! DeviceViewController
        newVC.currentDevice = device
        newVC.currentDevice?.setListeners(newVC, newVC, newVC, newVC)
        self.navigationController?.pushViewController(newVC, animated: true)
    }
    
    func didDisconnectFrom(_ device: ObviousDevice) {
        // Disconnect events can be handled here
    }
    
    func didFailToConnect() {
        // Connection failure events can be handled here
    }
}
