# Point-Cloud-iPhone-App

Point Clouds is an iOS app that records iPhone LiDAR data and exports it via a local HTTP server.
The app also allows the iphone to form a Bluetooth Low Energy (BLE) connection and export data.
As it stands the app cannot stream data in real time through a BLE connection. To approach this hurdle a potential solution lies in adjusting the RPI's Maximum Transmission Unit (MTU).  
 The repo is organized as follows:
 - `\go` contains Go client code for reading the data exported by the SensorExporter app.
 - `\PointClouds` contains the source code of the iOS app.


# First time running the app
The 'point clouds.xcodeproj' file cannot be opened with Xcode version 12 because of ARKit 5.
To get Xcode 13 beta, [click here](https://developer.apple.com/xcode/).

The point cloud app uses [CocoaPods](https://github.com/CocoaPods/CocoaPods) as its dependency manager, so you must have have it installed on your machine. It can be installed on a Mac with `brew install cocoapods`.

After installing CocoaPods, we need to download all required pods.
Go to the directory containing `Podfile`.
If you are using an ARM based Mac, you need to run the command in the x86 terminal with `arch -x86_64 pod install`.
Otherwise, run`pod install`.

Note: If you are also using the [SensorExporter](https://github.com/viamrobotics/SensorExporter) app and it is your first time you must also do the same procedure.

Open the `point clouds.xcworkspace` file.


# Bluetooth

**Connecting to RPI**
1. run: `sudo hciconfig hci0 piscan" & 'sudo bluetoothctl`
2. run app on phone
3. run: `scan on`
4. Look for the MAC address next to 'LiDAR Phone'
5. run: `connect <MAC address>`
6. on phone confirm connection request
7. run: `menu gatt` and `list-attributes <MAC address>`
8. find the characteristic (easily find with Crt+F "D6F60427")
9. copy line above the UUID
- e.g. `/org/bluez/hci0/dev_69_BD_81_7B_FA_4D/service0039/char003a`
- It is very important that the line you copy ends with `service0039/char003a` do not copy the one that ends with 'service0039'
10. run: `select-attribute </org/bluez/hci0/dev_69_BD_81_7B_FA_4D/service0039/char003a/this_should_be_copied_from_your_terminal>`
11. run: `notify on`
You should now be able to see a truncated point cloud streamed into the RPI
NOTE: running `read` will result in error
**Core Bluetooth**
Apple's [Core Bluetooth framework](https://developer.apple.com/documentation/corebluetooth) allows the iphone to act as either a central or peripheral device.
- Central devices scan for other devices. They access remote devices over a bluetooth low energy link using the GATT protocol.
- Peripheral devices advertise their presence and wait for connection requests. The infomation within a peripheral device is referenced by the name is its service
A popular example of a peripheral device is a heart rate monitor.
A service of a heart rate monitor is its heart rate service.
The characteristics which describe this service include: heart rate measurement and body sensor location.
With respect to us, a service of a iPhone is its camera service, and the characteristics which describe this service include: RBG pixel buffer for each frame, point cloud data, etc .. 

**Bluetooth - App Logic**

This app has the iphone acting as a peripheral.
1. On start-up the iphone advertises its presence.
2. A RPI scans for local bluetooth low energy devices and connects to the phone.
3. RPI connects to iPhone.
4. RPI queries services and characteristics of iPhone.
5. iPhone responds to query requests.

More on [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) and [ARKit](https://developer.apple.com/documentation/arkit/).
