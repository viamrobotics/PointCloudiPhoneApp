# Point-Cloud-iPhone-App

The 'point clouds.xcodeproj' file cannot be opened with Xcode version 12.
To get Xcode 13 beta, [click here](https://developer.apple.com/xcode/).

To run the app:
1. Open the 'point clouds.xcodeproj' file.
2. Click the button on the upper left side of the screen. It is to the left of the sideways triangle button. You should now see a side screen now.
3. Immediately below the button you just clicked there should be a row of icons.
4. Click on the leftmost icon. Icon looks like a folder.
5. You should now see a drop down menu containing this app's files.
6. There are two values called 'point clouds'. Click on point clouds that has the app store logo to the left of its name.
7. On your main screen, now, click 'Signing & Capabilities'.
8. In the 'Signing' drop down menu look at 'Team'.
9. You should see: 'Name (Personal Team)'.
10. Click on 'General'.
11. Under 'Indentity' change 'Bundle Identifier: Viam-Robotics.point-clouds' to 'Bundle Identifier: Viam-Robotics.point-clouds.<Name that shows up next to (Personal Team)>'.
12. Connect your phone to computer (USB to lightening).
13. In Xcode select your phone from the list of possible devices the app can run on. This is a drop down menu at the very top of the screen.
14. Click on the sideways triangle in the upper left hand corner of your Xcode window.


**Connecting to RPI**
1. run: 'sudo hciconfig hci0 piscan" & 'sudo bluetoothctl'
2. run app on phone
3. run: 'scan on'
4. Look for the MAC address next to 'LiDAR Phone'
5. run: 'connect <MAC address>'
6. on phone confirm connection request
7. run: 'menu gatt' & 'list-attributes <MAC address>'
8. find the characteristic (easily find with Crt+F "D6F60427")
9. copy line above the UUID
- e.g. /org/bluez/hci0/dev_69_BD_81_7B_FA_4D/service0039/char003a
- It is very important that the line you copy end with 'service0039/char003a' do not copy the one that ends with 'service0039'
10. run: 'select-attribute </org/bluez/hci0/dev_69_BD_81_7B_FA_4D/service0039/char003a/this_should_be_copied_from_your_terminal>'
11. run: 'notify on'
  
  you should now be able to see a truncated point cloud streamed into the RPI
  
  NOTE: running 'read' will result in error


**Core Bluetooth:**
Apple's [Core Bluetooth framework](https://developer.apple.com/documentation/corebluetooth) allows the iphone to act as either a central or peripheral device.
- Central devices scan for other devices. They access remote devices over a bluetooth low energy link using the GATT protocol.
- Peripheral devices advertise their presence and wait for connection requests. The infomation within a peripheral device is referenced by the name is its service

A popular example of a peripheral device is a heart rate monitor.
A service of a heart rate monitor is its heart rate service.
The characteristics which describe this service include: heart rate measurement and body sensor location.

**App Logic**:
This app has the iphone acting as a peripheral. On start-up the iphone advertises its presence. A RPI scans for local bluetooth low energy devices and connects to the phone. iPhone is generating point clouds. (~I believe that the type of data that represents a point cloud has to be turned into a service/characteristic and ~save generated point clouds to local database) RPI is discovered and connects to iPhone. RPI queries contents of iPhone. iPhone responds to query requests.



Below is a description of each file.

**AppDelegate:** Handles lifecycle and setup.
- E.g. If the app is launched what existing code needs to be called on.
- E.g. If the app is now in the background what existing code needs to be called on so the app can be used again at a later point.

**Shaders & ShaderTypes:** All the rendering functions that we need to display the camera's view on a user's screen and add on point clouds.

**Renderer:** Logic of how rendering functions are used. Contains Rendender class that houses [ARSession](https://developer.apple.com/documentation/arkit/arsession) which gives us the [ARFrame](https://developer.apple.com/documentation/arkit/arframe).


**ViewController:** Manages UI and background functionality. ViewController is called on by the AppDelegate if the app successfully launches. The conents of the file manage the devices bluetooth behavior and calls to **Renderer**.


* More on [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) and [ARKit](https://developer.apple.com/documentation/arkit/) will be added.
