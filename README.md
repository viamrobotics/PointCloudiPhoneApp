# Point-Cloud-iPhone-App


This app is the union of the [Displaying a Point Cloud Using Scene Depth](https://developer.apple.com/documentation/arkit/environmental_analysis/displaying_a_point_cloud_using_scene_depth) app and the [Transferring Data Between Bluetooth Low Energy Devices](https://developer.apple.com/documentation/corebluetooth/transferring_data_between_bluetooth_low_energy_devices) app


The point clouds.xcodeproj file cannot be opened with Xcode version 12.
To get Xcode 13 beta, [click here](https://developer.apple.com/xcode/)

Below is a description of each file.

**AppDelegate:** Handles lifecycle and setup.
E.g. If the app is launched what existing code needs to be called on
E.g. If the app is now in the background what existing code needs to be called on so the app can be used again at a later point

**Shaders & ShaderTypes:** All the rendering functions that we need to display the camera's view on a user's screen and add on the point clouds.

**Renderer:** Logic of how rendering functions are used. Contains Rendender class which houses the [ARSession](https://developer.apple.com/documentation/arkit/arsession) which gives us the [ARFrame](https://developer.apple.com/documentation/arkit/arframe)

**ViewController:** Manages UI and background functionality. ViewController is immediately called on by the AppDelegate if the app successfully launches. Calls on MyPeripheralManger to get start bluetooth and then Renderer to begin generating point clouds.

**MyPeripheralManager:** How the iphone behaves as a peripheral. Logic behind advertising, connecting, and responding to requests from a central bluetooth low energy device (e.g. raspberry-pi)

