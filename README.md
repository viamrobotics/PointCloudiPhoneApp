# PointCloudiPhoneApp

Point Clouds is an iOS app that records iPhone LiDAR data and exports it via a local HTTP server.
The app also allows the iPhone to form a Bluetooth Low Energy (BLE) connection and export data.
As it stands the app cannot stream data in real time through a BLE connection. To approach this hurdle, a potential solution lies in adjusting the RPI's Maximum Transmission Unit (MTU) and potentially establishing an L2CAP connection.
 The repo is organized as follows:
 - `\go` contains Go client code for reading the data exported by the PointCloudiPhoneApp.
 - `\PointCloudiPhoneApp` contains the source code of the iOS app.

## Usage
### Setting up the app
The 'point clouds.xcodeproj' file cannot be opened with Xcode version 12 because of ARKit 5.
To get Xcode 13 beta, [click here](https://developer.apple.com/xcode/).

The point cloud app uses [CocoaPods](https://github.com/CocoaPods/CocoaPods) as its dependency manager, so you must have have it installed on your machine. It can be installed on a Mac with `brew install cocoapods`.

After installing CocoaPods, we need to download all required pods.
Go to the directory containing `Podfile`.
If you are using an ARM based Mac, you need to run the command in the x86 terminal with `arch -x86_64 pod install`.
Otherwise, run`pod install`.

Open the `point clouds.xcworkspace` file.

The `iplidar.json` file `host` value needs to be entered to run the web ui.
To get the `host` value run the app with your phone connected to the computer.
Running the app from Xcode will return something of the form:
`2021-11-08 20:48:09.377920-0500 point clouds[31005:3747646] Our IP address: abc.def.ghi.lmn`

Note: The port value is by default set to 3000 on the app side and does not need to be changed in the json file

### Using the app to get point cloud data
First ensure that the iPhone and the device running the Go client are on the same WiFi network.
Open the app and then run the client code.

### ARKit
The point clouds app uses ARKit5 to get point cloud data.
To orient itself in R3 the iPhone uses `ARWorldTrackingConfiguration` which is defined by Apple as: 'a class that tracks the device's movement with six degrees of freedom (6DOF): the three rotation axes (roll, pitch, and yaw), and three translation axes (movement in x, y, and z).'
Alternatively, we can use `AROrientationTrackingConfiguration' which is defined by Apple as: 'a class that tracks the device's movement with three degrees of freedom (3DOF): specifically, the three rotation axes (roll, pitch, and yaw)' 

IMPORTANT: Apple states that the number of points in a pointcloud for a given frame is non-constant. So at time `a` our pointcloud, `p_a`, may contain `b` many points, and at time `c` our pointcloud, `p_c`, may contain `d` many points. Assuming `a != c`, we cannot state that `b = d`. This is because all the points that are in `p_a` are not allowed to be in `p_c` as they are non-new. Hence, the intersection of `p_a` and `p_b` is the empty set.
 
### Bluetooth

**Connecting to RPI**
1. on RPI run: `sudo hciconfig hci0 piscan" & 'sudo bluetoothctl`
2. run app on phone
3. on RPI run: `scan on`
4. Look for the MAC address next to 'LiDAR Phone'
5. on RPI run: `connect <MAC address>`
6. on phone confirm connection request
7. on RPI run: `menu gatt` and `list-attributes <MAC address>`
8. on RPI find the characteristic (easily find with Crt+F "D6F60427")
9. on RPI copy line above the UUID
- e.g. `/org/bluez/hci0/dev_69_BD_81_7B_FA_4D/service0039/char003a`
- It is very important that the line you copy ends with `service0039/char003a` do not copy the one that ends with 'service0039'
10. on RPI run: `select-attribute </org/bluez/hci0/dev_69_BD_81_7B_FA_4D/service0039/char003a/this_should_be_copied_from_your_terminal>`
11. on RPI run: `notify on`
You should now be able to see a truncated point cloud streamed into the RPI
NOTE: running `read` will result in error
**Core Bluetooth**
Apple's [Core Bluetooth framework](https://developer.apple.com/documentation/corebluetooth) allows the iPhone to act as either a central or peripheral device.
- Central devices scan for other devices. They access remote devices over a bluetooth low energy link using the GATT protocol.
- Peripheral devices advertise their presence and wait for connection requests. The infomation within a peripheral device is referenced by the name is its service
A popular example of a peripheral device is a heart rate monitor.
A service of a heart rate monitor is its heart rate service.
The characteristics which describe this service include: heart rate measurement and body sensor location.
With respect to us, a service of a iPhone is its camera service, and the characteristics which describe this service include: RBG pixel buffer for each frame, point cloud data, etc .. 

**Bluetooth - App Logic**

This app has the iPhone acting as a peripheral.
1. On start-up the iphone advertises its presence.
2. A RPI scans for local bluetooth low energy devices and connects to the phone.
3. RPI connects to iPhone.
4. RPI queries services and characteristics of iPhone.
5. iPhone responds to query requests.

More on [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) and [ARKit](https://developer.apple.com/documentation/arkit/).
