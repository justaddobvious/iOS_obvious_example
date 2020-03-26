# iOS_obvious_example
This example iOS app provides a reference implementation for integrating the Obvious mobile SDK into an iOS project.

## Overview
The Obvious mobile API enables apps to communicate with Bluetooth Smart devices that implement the BLE Obvious Platform Service Profile. This allows the app to update the device to enable or disable optional features. The status of optional features are configured using the Obvious Cloud Platform.

## Requirements
- Xcode 10.2 or higher
- Swift 5 or higher
- iOS 10.0 or higher

## Installations
The Obvious mobile API library can be installed using CocoaPods. CocoaPods is a dependency manager for Swift and Objective-C Cocoa projects (more information can be found on https://cocoapods.org/).

CocoaPods is built with Ruby and is installable with the default Ruby available on macOS. It can be installed using the default Ruby install.

```bash
$ sudo gem install cocoapods
```

The library also makes use of the dependency, Alamofire. As such, this pod must also be installed. Create a text file named `Podfile` in your Xcode project directory and add the following to your Podfile:

```ruby
platform :ios, '10.0'

target 'MyApp' do
  use_frameworks!
  
  pod 'ObviousAPI', :http => 'https://developer.theobvious.io/artifactory/ios-release-local/ObviousAPI_iOS_1_11_0_Swift_5_1.zip'
end
```

[View source](https://github.com/justaddobvious/iOS_obvious_example/blob/master/App/Podfile)

Install the dependencies using the following command:

```bash
$ pod install
```

Make sure to always open the Xcode workspace instead of the project file when building your project:

```bash
$ open App.xcworkspace
```

## Installation Troubleshooting
If there are issues with the Cocoapod integration (eg. issues with updating the library version), comment out the Obvious Library pod:

```ruby
platform :ios, '10.0'

target 'MyApp' do
  use_frameworks!
  
  # pod 'ObviousAPI', :http => 'https://developer.theobvious.io/artifactory/ios-release-local/ObviousAPI_iOS_1_11_0_Swift_5_1.zip'
end
```

Reinstall the pods and clear the pod cache by executing the following commands:

```bash
$ pod install
$ pod cache clean --all
```

Then, uncomment the ObviousAPI library pod. 

```ruby
platform :ios, '10.0'

target 'MyApp' do
  use_frameworks!
  
  pod 'ObviousAPI', :http => 'https://developer.theobvious.io/artifactory/ios-release-local/ObviousAPI_iOS_1_11_0_Swift_5_1.zip'
end
```

And install the dependencies again using `pod install`.

```bash
$ pod install
```

## Using the Obvious Mobile API
The Obvious API does not independently manage Bluetooth connections with devices. The app developer must implement all necessary methods for interacting with the Bluetooth device. This includes scanning, pairing, connecting, reading and writing characteristics and configuring notification or indications. The API will handle the processing of the data protocol used by the BLE Obvious Platform Service Profile.

The full setup can be found in the [`ObviousDevice`](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift) class implementation.

The `OcelotFeatureManager` class handles the process of updating the feature status on a device. As the manager processes the feature update, it will pass status information to a callback that is implemented by the `OcelotFeatureEventListener` protocol. The developer API key must also be set so that HTTP requests can be performed correctly.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    private var featureManager: OcelotFeatureManager!
    ...

    init(peripheral: CBPeripheral) {
        super.init()
        featureManager = OcelotFeatureManager.getFeatureManager()
        featureManager.setFeatureEventListener(self)
        featureManager.setAPIKey("Your API Key")
        ...
    }
    
    ...
    
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L35) 

The manager needs to be initialized prior to connecting to the Bluetooth device being updated. After setting up the listener callback, we need to tell the manager how to communicate with the Bluetooth device to send and receive data.

When instantiating the ObviousDevice class, it is necessary to add the callback to the connector. This is done by calling the `setConnectorCallback(_:)` method from the connector instance to the ObviousDevice instance.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    private var featureManager: OcelotFeatureManager!
    private var deviceConnector: OcelotDeviceConnector!
    ...
    
    init(peripheral: CBPeripheral) {
        super.init()
        featureManager = OcelotFeatureManager.getFeatureManager()
        featureManager.setFeatureEventListener(self)
        featureManager.setAPIKey("Your API Key")
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        ...
    }
    
    ...
    
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L35) 

## Notifications and Indications
There are a number of characteristics in the Obvious Platform service profile that require notification to receive data and status information from the device. The list of these services and corresponding characteristics are provided to the app as a map of type `[CBUUID: [CBUUID]]`, with the services' CBUUID being the keys and characteristics' CBUUID being the values, through the `getServerInformation()` method of the OcelotDeviceConnector class. The app must enable the notifications and indications for the Bluetooth device through the CoreBluetooth library after all services have been discovered for the device.

All subscribed characteristics should be stored so that they can be accessed during a read or write request by the `OcelotFeatureManager`. A way to do this is with a dictionary that stores the string representation of the characteristic UUID and the corresponding CBCharacterisitc.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    private var featureManager: OcelotFeatureManager!
    private var deviceConnector: OcelotDeviceConnector!

    private var serviceInfo: [CBUUID: [CBUUID]] = [:]
    private var discoveredServices: Set<String> = Set<String>()
    private var characteristicDict: [String: CBCharacteristic] = [:]
    ...

    init(peripheral: CBPeripheral) {
        super.init()
        featureManager = OcelotFeatureManager.getFeatureManager()
        featureManager.setFeatureEventListener(self)
        featureManager.setAPIKey("Your API Key")
        deviceConnector = featureManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        if let serviceCharMap = deviceConnector.getServerInformation() {
            self.serviceInfo = serviceCharMap
        }
    }
    ...
    
    // Discovered peripheral services will be received from this callback
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            // Keep track of discovered services; this can be used to track when all characteristics
            // have been discovered for each corresponding discovered service. When this condition is 
            // fulfilled, and all characteristic notifications and indications have been enabled, 
            // Obvious related methods can then be called
            discoveredServices = Set(services.map { service in service.uuid.uuidString })
            for service in services {
                // Check if we want to subscribe to this service
                if let characteristicUUIDs = serviceInfo[service.uuid] {
                    peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
                }
            }
        }
        
        ...
        
    }
    
    // Discovered peripheral characteristics will be received from this callback
    func peripheral(_ peripheral: CBPeripheral, 
                    didDiscoverCharacteristicsFor service: CBService, 
                    error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // Keep track of discovered characteristics in a dictionary; this will be used for the 
                // implementation of the OcelotDeviceConnectorCallback protocol
                characteristicDict[characteristic.uuid.uuidString] = characteristic
                peripheralObj?.setNotifyValue(true, for: characteristic)
            }
        }
        if discoveredServices.contains(service.uuid.uuidString) {
            discoveredServicesCounter += 1
        }
        if discoveredServicesCounter == discoveredServices.count {
            // Once all characteristics have been discovered for each corresponding service,
            // Obvious related functionalities, like starting feature updates may be called
            // featureManager.startFeatureUpdate()

            discoveredServicesCounter = 0
        }

        ...

    }

    ...
    
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L83)

## Interacting with the BLE Obvious Device
Interacting with Bluetooth characteristics is done by implementing the `OcelotDeviceConnectorCallback` protocol. The callbacks implemented by the protocol will be used to send data to the Bluetooth device, as well as requesting the device to disconnect and reconnect.

When the Obvious layer sends a read or write request callback, it uses the string representation of the service UUID and characteristic UUID being read or written. In addition, the callback returns a boolean, indicating whether the characteristic exists or not. As such, we load the needed `CBCharacteristic` from our `characteristicDict` dictionary. If the characteristic exists, the request is made, and we return `true`, otherwise we return `false`.

In addition, the Obvious Layer may also request the device to be disconnected and then reconnected. This is done through the `requestDeviceDisconnect()` and `requestDeviceConnect()` callbacks respectively.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {
    
    ...
    
    func requestCharacteristicWrite(serviceId: String,
                                    characteristicId: String,
                                    rawdata: [UInt8]) -> Bool {
        guard let characteristic = characteristicDict[characteristicId] else { return false }
        peripheral.writeValue(Data(rawdata), for: characteristic, type: .withResponse)
        return true
    }
    
    func requestCharacteristicWriteWithoutResponse(serviceId: String,
                                                   characteristicId: String,
                                                   rawdata: [UInt8]) -> Bool {
        guard let characteristic = characteristicDict[characteristicId] else { return false }
        peripheral.writeValue(Data(rawdata), for: characteristic, type: .withoutResponse)
        return true
    }
    
    func requestCharacteristicRead(serviceId: String,
                                   characteristicId: String) -> Bool {
        guard let characteristic = characteristicDict[characteristicId] else { return false }
        peripheral.readValue(for: characteristic)
        return true
    }
    
    func requestDeviceConnect() {
        // Request the device to connect here
        BluetoothInteractor.shared.connectToDevice(by: peripheral.identifier)
    }
    
    func requestDeviceDisconnect() {
        // Request the device to disconnect here
        BluetoothInteractor.shared.disconnectCurrentDevice()
    }

    func getOcelotProductIdentifier() -> String? {
        // This should return the product identifier for the device
        return <PRODUCT_ID_HERE>
    }
    
    ...
    
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L141)

## Processing Bluetooth Data
The connector also provides methods for passing Bluetooth data received from the device to the Obvious API so that it can properly interpret the feature update data protocol. The data received from the CoreBluetooth CBPeripheral delegate callback methods, `peripheral(_:didUpdateValueFor:error:)` and `peripheral(_:didWriteValueFor:error:)`, should be passed on to the connector.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    ...
    
    // Callback invoked when you retrieve a specified characteristic's value, 
    // or when the device notifies your app that the characteristic's value has changed.
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if characteristicDict[characteristic.uuid.uuidString] != nil {
            if let data = characteristic.value {
                deviceConnector.onUpdateDeviceData(characteristic.uuid.uuidString, [UInt8](data))
            }
            if error != nil, let bleError = error as NSError? {
                // If an error occurred, handle the error code
                deviceConnector.onReadStatus(characteristic.uuid.uuidString, UInt8(bleError.code))
            }
        }
    }
    
    // Callback invoked when you request to write data to a characteristic's value.
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        let status: UInt8 = error == nil ? OcelotServiceConstants.WRITE_DATA_SUCCESS : OcelotServiceConstants.WRITE_DATA_FAILURE
        if characteristic.uuid.uuidString != OcelotServiceConstants.BLE_CHARACTERISTIC_OBVIOUS_DATA {
            deviceConnector.onWriteStatus(characteristic.uuid.uuidString, status)
        }
    }
    
    ...
    
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L113)

The connector methods receive the characteristic UUID, and the raw data bytes or write status from the delegate callbacks. This data is parsed and processed by the Ocelot API to complete the feature update process.

## Handling Connection State Changes
There are situations where the Obvious API will need to perform actions when the app connects to or disconnects from the Bluetooth device. The connection and disconnection events need to be passed to the API through the connector and feature manager class when the CoreBluetooth CBCentralManager delegate callback methods, `centralManager(_:didConnect:)` and `centralManager(_:didDisconnectPeripheral:error:)`, are notified of the connection state change.

```swift
extension BluetoothInteractor: CBCentralManagerDelegate {

    ...
    
    // Connected to peripheral
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        obviousDevice?.handleConnectionState(peripheral.state.rawValue)
        ...
    }
    
    // Disconnected from peripheral
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        obviousDevice?.handleConnectionState(peripheral.state.rawValue)
        ...
    }
    
    ...
    
}

class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    ...
    
    func handleConnectionState(_ state: Int) {
        if state == OcelotDeviceConnector.CONNECTION_STATE_CONNECTED {
            peripheralObj.discoverServices(Array(serviceInfo.keys))
        }
        featureManager.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
        deviceConnector.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
    }
    
    ...
    
}

```
- View source for [`BluetoothInteractor`](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/BluetoothInteractor.swift#L77) and [`ObviousDevice`](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L131).

## Starting Feature Updates
After the `OcelotFeatureManager` class, connector and callbacks have been configured, the app is ready to start the feature check and update process. Before starting the update, the app must connect to the Bluetooth device, and discover all relevant services and characteristics. The `OcelotFeatureManager` class will handle the details of the update process; all the app needs to do is call the `startFeatureUpdate()` method of the manager after successful connection and all services and characteristics have been discovered and subscribed to. The status and progress of the update will be returned to the app through the `onFeatureUpdateStatus(_:)` callback.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {
    ...
    
    // Discovered peripheral characteristics will be received from this callback
    func peripheral(_ peripheral: CBPeripheral, 
                    didDiscoverCharacteristicsFor service: CBService, 
                    error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // Keep track of discovered characteristics in a dictionary; this will be used for the 
                // implementation of the OcelotDeviceConnectorCallback protocol
                characteristicDict[characteristic.uuid.uuidString] = characteristic
                peripheralObj?.setNotifyValue(true, for: characteristic)
            }
        }
        if discoveredServices.contains(service.uuid.uuidString) {
            discoveredServicesCounter += 1
        }
        if discoveredServicesCounter == discoveredServices.count {
            // Once all characteristics have been discovered for each corresponding service,
            // Obvious related functionalities, like starting feature updates may be called
            featureManager.startFeatureUpdate()

            discoveredServicesCounter = 0
        }

        ...

    }
    
    ...

    // Receive status updates of the feature update from the following callback
    func onFeatureUpdateStatus(_ status: Int) {
        if status == FeatureUpdateConstants.SUCCESS {
        // Call this method to query feature list
        // featureManager.getFeatureList()
        }
    }

    ...
    
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L95)

## Verifying Feature Enable and Toggle Statuses
The app can ask the device for the enable status of the supported features at any time after connecting to the Bluetooth device. This status represents whether the feature of interest has been purchased (enabled), or not (disabled) by your end user customers. Using the `OcelotFeatureManager` method, `getFeatureList()`, the app can query the cloud service for a list of all the features supported by the product, and then check the status of each of the features with the connected device.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    ...
    private var availableFeatures: [String: Int] = [:]
    ...
    
    // Receive status updates of the feature update from the following callback
    func onFeatureUpdateStatus(_ status: Int) {
        if status == FeatureUpdateConstants.SUCCESS {
        // Call this method to query feature list
        featureManager.getFeatureList()
        }
    }
    
    ...
    
    // Called once the feature list is returned from the cloud
    func onFeatureList(_ features: [String : Int]?) {
        if let featureList = features {
            availableFeatures = featureList
        }
        ...
    }
    
    ...
    
}
```

- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L177)

Once the list of features has been obtained, the status of each supported feature can be queried one by one from the device using the manager method, `checkFeatureStatus(featureid:)`. The state of the feature is returned through the `onCheckFeatureStatus(_:_:)` callback, which is implemented by a class that conforms to the `OcelotFeatureEventListener` protocol.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    ...
    private var availableFeatures: [String: Int] = [:]
    ...
    
    // Called once the feature list is returned from the cloud
    func onFeatureList(_ features: [String : Int]?) {
        if let featureList = features {
            availableFeatures = featureList
        }

        for  (featureName, id) in availableFeatures {
            let id: Int = availableFeatures[featureName]
            featureManager.checkFeatureStatus(featureid: id)
        }
        ...
    }
    
    // Callback invoked when enable status of a feature has been successfully read from a device.
    func onCheckFeatureStatus(_ featureid: Int, _ status: Int) {
        // Handle the status of the checked feature
        // Status of 0 is disabled
        // Status of 1 is enabled
    }
    
    ...
    
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L251)

Features that have been enabled may also be toggled on and off, if it is supported on the feature. As discussed before, when the status of a feature is queried from calling the `checkFeatureStatus(featureid:)` method, the `onCheckFeatureStatus(_:_:)` callback is called. Instead of handling the `onCheckFeatureStatus(_:_:)` callback from the `OcelotFeatureEventListener` protocol, handle the `onCheckFeatureStatus(_:_:)` method from the `OcelotTogglerEventListener` protocol. 

The status that is returned from the `onCheckFeatureStatus(_:_:)` callback will be of type `OcelotFeatureStatus`, an Obvious enum that represents both the enable status and toggle status of the feature. The toggle status can be accessed through the computed property `toggleState`, which is of type `OcelotToggleStatus`, an Obvious enum that represents the toggle status of the feature. Please refer to the iOS Obvious API documentation regarding enums for more detailed information regarding each of the toggle status types and how to appropriately handle them. 

```swift
extension class ObviousDevice: OcelotToggleEventListener {

    ...
    private var availableFeatures: [String: Int] = [:]
    ...
    
    // Called once the feature list is returned from the cloud
    func onFeatureList(_ features: [String : Int]?) {
        if let featureList = features {
            availableFeatures = featureList
        }

        for  (featureName, id) in availableFeatures {
            let id: Int = availableFeatures[featureName]
            featureManager.checkFeatureStatus(featureid: id)
        }
        ...
    }
    
    // Callback invoked when enable status and toggle status of a feature has been read from a device.
    func onCheckFeatureStatus(_ featureid: Int, _ status: OcelotFeatureStatus) {
        // Handle the status of the checked feature.
        //
        // Please refer to the iOS Obvious API documentation regarding `OcelotFeatureStatus` and 
        // `OcelotToggleStatus` for a detailed summary of what each status type represents.
        
    }
    
    ...
    
}
```

## Toggling Features
Toggling a feature on or off enables or disables the functionality of the feature respectively. For example, a feature can be toggled on by either calling `toggleFeature(featureid:)` on that feature when it has already been toggled off, or setting the feature's toggle status to `OcelotToggleStatus.Activated` through the `setToggleFeatureStatus(featureid:toggleState:)` method. The updated toggle status will be returned from the `didToggleFeatureStatus(_:_:)` callback. These methods allow for your end user customers to be able to turn their features on and off depending on the situation.

```swift

...

// Trigger a toggle for a particular feature by calling the following method.
featureManager.toggleFeature(featureid: id)

...

extension class ObviousDevice: OcelotToggleEventListener {

    ...

    func didToggleFeatureStatus(_ featureId: Int, _ status: OcelotFeatureStatus) {
        // Handle the new enable and toggle status of the feature that has been toggled.
    }

    func featureStatusFailure() {
        // Should this callback be called, the statuses of the features must be
        /// checked again by calling `onCheckFeatureStatus(_:_:)` on all features to ensure
        /// the validity of the feature statuses.
    }
    
    ...
    
}
```

## Checking Firmware Version
Similarly to starting a feature update, the configurations for the `OcelotFirmwareManager` class, connector and callbacks must be implemented before starting a firmware check or OTA upgrade. The `OcelotFirmwareManager` class handles the process of checking and updating firmware on a device. Before starting a process, the developer API key must be set so that HTTP requests can be performed correctly, and the app must connect to the Bluetooth device, and discover all relevant services and characteristics. 

To check the current firmware version on a device, and if there is any new firmware updates available for it, the `upgradeCheck(_:_:)` method is to be called. The result will be returned through the `onFirmwareUpgradeAvailable(currentVersion:newFirmwareInfo:)` callback from the `OcelotFirmwareAvailableListener` protocol.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {

    ...
    private var firmwareManager: OcelotFirmwareManager!
    ...
    
    init(peripheral: CBPeripheral) {
        ...
        firmwareManager = OcelotFirmwareManager.getFirmwareManager()
        firmwareManager.setEventListener(self)
        firmwareManager.setAPIKey("Your API Key")
    }
    
    ...

    public func startFirmwareCheck() {
        deviceConnector = firmwareManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        // Called to start a firmware check
        firmwareManager.upgradeCheck(<MOBILE_APP_VERSION>, self)
    }
    
    ...

    func handleConnectionState(_ state: Int) {
        if state == OcelotDeviceConnector.CONNECTION_STATE_CONNECTED {
            peripheralObj.discoverServices(Array(serviceInfo.keys))
        }
        featureManager.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
        // In addition, the OcelotFirmwareManager also wants to listen to connection and disconnection 
        // events
        firmwareManager.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
        deviceConnector.onConnectionStateChange(OcelotDeviceConnector.CONNECTION_STATUS_SUCCESS, state)
    }
    
    ...

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
        //
        // newFirmwareInfo: Optional data struct containing the details of the new firmware available.
        // OcelotFirmwareInfo has the following structure:
        //
        // public struct OcelotFirmwareInfo {
        //
        //     public let versionCode: Int64
        //
        //     public let versionName: String
        //
        //     public let releaseNotes: String
        //
        //     public let upgradeMessage: String
        //
        // }

    }
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L320)

## Starting Firmware Upgrades
Once the configurations for the `OcelotFirmwareManager` class, connector and callbacks have been setup, a firmware OTA upgrade process can be started by calling the `startFirmwareUpgrade(_:)` method from an instance of the `OcelotFirmwareManager` class. Note, that the app must be connected to a BLE Obvious device, and all relevant services and characteristics must be discovered. As the manager processes the firmware upgrade, it will update the app of the upgrade progress as a percentage through the `onFirmwareProgressUpdate(_:_:)` callback, and update the app of the upgrade status through the `onFirmwareUpgradeStatus(_:)` callback; both of which are implemented by the `OcelotFirmwareEventListener` protocol.

```swift
class ObviousDevice: NSObject, CBperipheralDelegate, OcelotDeviceConnectorCallback, OcelotFeatureEventListener {
    
    ...
    private var firmwareManager: OcelotFirmwareManager!
    ...
    
    init(peripheral: CBPeripheral) {
        ...
        firmwareManager = OcelotFirmwareManager.getFirmwareManager()
        firmwareManager.setEventListener(self)
        firmwareManager.setAPIKey("Your API Key")
    }

    ...

    public func startFirmwareUpgrade() {
        deviceConnector = firmwareManager.getDeviceConnector()
        deviceConnector.setConnectorCallback(self)
        // Called to start a firmware upgrade
        firmwareManager.startFirmwareUpgrade(<MOBILE_APP_VERSION>)
    }
    
    ...
    
}

extension ObviousDevice: OcelotFirmwareEventListener {
    func onFirmwareProgressUpdate(_ serialNumber: String, _ percent: Int) {
        // Progress of the firmware upgrade will be received from this callback.
    }
    
    func onFirmwareUpgradeStatus(_ status: OcelotFirmwareManager.OcelotFirmwareUpgradeStatus) {
        if status == .SUCCESS {
            // Handle the event of a successful firmware upgrade.
        } else {
            // Handle the event of a firmware upgrade failure.
        }
    }
}
```
- [View source](https://github.com/justaddobvious/iOS_obvious_example/blob/007a3f38a9e5a2936fd5110c459d756c603d155b/App/ExampleObviousApp/ExampleObviousApp/Bluetooth/ObviousDevice.swift#L285)


On successful completion of the OTA upgrade, the Obvious API will request the connected device reboot itself so that the newly updated firmware can be validated and started up. Because of this, the connection with the device will be lost after the update. The app must reestablish the Bluetooth connection in order to continue interacting with the device.

## Purchasing Features
The `OcelotCatalogInteractor` class handles processes related to purchasing features. This includes providing a catalog of purchasable features, and checking out selected catalogs of features for purchasing. The developer API key must also be set so that HTTP requests can be performed correctly.

In order for your end user customers to be able to purhcase features, first, present the catalog from which features can be pruchased from. The default catalog can be obtained from calling the `getDefaultCatalog()` method from the `OcelotCatalogInteractor` class. The resulting catalog will be returned as a list of `CatalogItem` from the `onCatalogListSuccess(_:)` callback, which is implemented by the `OcelotCatalogListResultListener` protocol.

The `CatalogItem` struct is a Obvious value type that represents a purchasable bundle of feature or features that can be purchased by the end user.

```swift
class StoreViewModel: OcelotCatalogListResultListener {
    
    var catalogList: [CatalogItem] = []

    init() {
        ...

        catalogInteractor = OcelotCatalogInteractor.getCatalogInteractor()
        catalogInteractor.setAPIKey("Your API Key")
        catalogInteractor.setCheckoutListener(self)
        catalogInteractor.setCatalogListListener(self)
        catalogInteractor.getDefaultCatalog()

        ...
    }


    ...

    func onCatalogListSuccess(_ catalogList: [CatalogItem]) {
        // Please refer to the iOS Obvious API documentation regarding the `CatalogItem` struct
        // for a detailed summary of each of its properties.
        self.catalogList = catalogList
        // The catalog list can be displayed to the user.
    }
    
    func onCatalogListRequestFail(_ error: String?) {
        // Handle the event of a catalog list request failure.
    }
}
```

If an end user requests to purchase a selected list of `CatalogItem`. The purhcase checkout process is initiated by the `checkoutCart(checkout:serialNumber:productIdentifier:)` method from the `OcelotCatalogInteractor` class. The checkout result will be finished processing once either the `onCheckoutCartSuccess(_ totalPrice:_ cartId:)` method or `onCheckoutCartFail(_ error:)` method is called back, which indicate a checkout success or failure respectively. These two callbacks are implemented from the `OcelotCatalogCheckoutResultListener` protocol.

```swift
extension StoreViewModel: OcelotCatalogCheckoutResultListener {

    ...

    func checkoutItems(items: [CatalogItem], serial: String, productIdentifier: String) {
        // Call the following method to start the checkout process on catalog items that are to be purchased.
        catalogInteractor.checkoutCart(checkout: items, serialNumber: serial, productIdentifier: productIdentifier)
    }
    
    func onCheckoutCartSuccess(_ totalPrice: Int, _ cartId: Int) {
        // Handle checkout cart success event here.
        //
        // The callback returns the total price in cents, as an integer, as well as the cartId, 
        // a unique identifier that represents the current successful checked out features.
        //
        // The cartId will used as a parameter when starting the payment process for when the 
        // end user chooses to confirm the catalog items that they have selected to purchase.
    }
    
    func onCheckoutCartFail(_ error: String?) {
        // Handle checkout cart failure event here.
    }

    ...

}

```

The end user can confirm their purchase by starting the payment process through the `startPaymentProcessing(cardNumber:cardExpMonth:cardExpYear:cardCVC:cartId:serialNumber:productId:)` method from the `OcelotPaymentClient` class. The `OcelotPaymentClient` class handles the payment process of purhcasing catalog items. The payment will be finished processing once either the `onCheckoutPaySuccess()` method or `onCheckoutPayFail(_ error:)` method is called back, which indicate payment processing success or failure respectively. These two callbacks are implemented from the `OcelotCatalogCheckoutResultListener` protocol.

Sometimes a payment may require additional authentication. If this is the case, the method `onCheckoutPayActionRequired(_ paymentSecret:)` is called back instead. The `OcelotPaymentClient` instance must authenticate the payment by calling `authenticatePayment(viewController:cartId:paymentSecret:isPresentingApplePay:)` method, passing the payment secret into it. After calling the method to authenticate the payment, the `onCheckoutPaySuccess()` method or `onCheckoutPayFail(_ error:)` method is called back.

```swift
class StoreViewModel: OcelotCatalogListResultListener {
    
    ...

    init() {
        ...

        catalogInteractor = OcelotCatalogInteractor.getCatalogInteractor()
        catalogInteractor.setAPIKey("Your API Key")
        catalogInteractor.setCheckoutListener(self)
        catalogInteractor.setCatalogListListener(self)
        catalogInteractor.getDefaultCatalog() 
        paymentClient = OcelotPaymentClient.getPaymentClient(obviousClient: catalogInteractor, listener: self)

        ...
    }

    ...

}

extension StoreViewModel: OcelotCatalogCheckoutResultListener {

    ...

    func startPaymentProcess(cardNumber: String, cardExpMonth: UInt, cardExpYear: UInt, cardCVC: String, cartId: Int, serialNumber: String, productId: String) {
        // Call the following method to start the payment processing for the catalog items to be purchased.
        paymentClient?.startPaymentProcessing(cardNumber: cardNumber,
                                              cardExpMonth: cardExpMonth,
                                              cardExpYear: cardExpYear,
                                              cardCVC: cardCVC,
                                              cartId: cartId,
                                              serialNumber: serialNumber,
                                              productId: productId)
    }

    func onCheckoutPayActionRequired(_ paymentSecret: String) {
        // If a payment requires additional authentication, pass the payment secret from this 
        // callback to the payment client method `authenticatePayment(viewController:cartId:paymentSecret:isPresentingApplePay:)`.
        paymentClient?.authenticatePayment(viewController: self, cartId: cartId, paymentSecret: paymentSecret, isPresentingApplePay: false)
    }
    
    func onCheckoutPaySuccess() {
        // Handle payment processing success event here.
    }
    
    func onCheckoutPayFail(_ error: String?) {
        // Handle payment processing failure event here.
    }

    ...

}

```
