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

public struct OcelotFeatureInfo {
    var id: Int
    var name: String
    var active: Bool
}

protocol ObviousDeviceDelegate: AnyObject {
    func didUpdateFeatureUpdateStatus(status: Int)
    func didUpdateProvisionStatus(status: Int)
    func didUpdateSerialNumber(serialNumber: String?)
    func didFinishFeatureListStatusCheck(featureList: [OcelotFeatureInfo])
    func didCheckFirmware(currentVersion: String, updateAvailable: Bool)
    func didUpdateFirmwareProgress(serialNumber: String, percent: Int)
    func didFirmwareUpgradeSuccess()
    func didFirmwareUpgradeFail()
}
