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

public struct DeviceInfo {
    let name: String
    let uuid: UUID
}

protocol BluetoothInteractorDelegate: AnyObject {
    func didManagerPowerOn() 
    func didDiscoverPeripheral(info: DeviceInfo)
    func didConnectTo(_ device: ObviousDevice)
    func didDisconnectFrom(_ device: ObviousDevice)
    func didFailToConnect()
}
