// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import SwiftUI
import AVFoundation

/// The drop down list for macOS to select the camera in the event that there are multiple cameras available.
public struct CameraPicker : View {
  @Binding var cameraName : String

  public init(cameraName: Binding<String>) {
    _cameraName = cameraName
  }

  public var body : some View {
#if os(macOS) || targetEnvironment(macCatalyst)
    Picker(selection: $cameraName, label: Text("Choose a camera") ) {
      ForEach( cameraList, id: \.self) { cn in
        Text(cn)
      }
    }
#else
    EmptyView()
#endif
  }

#if os(iOS)
  static public var _cameraList : [AVCaptureDevice] { get {
    let aa = ProcessInfo.processInfo
    let bb = aa.isiOSAppOnMac || aa.isMacCatalystApp
    let availableDeviceTypes : [AVCaptureDevice.DeviceType] = [.builtInTrueDepthCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera, .builtInTripleCamera]
    let foundVideoDevices = AVCaptureDevice.DiscoverySession.init(deviceTypes: availableDeviceTypes, mediaType: .video , position: bb ? .unspecified :  /* frontCamera ? .front : */ .back).devices
    return foundVideoDevices
  }}
#elseif os(macOS)
  static public var _cameraList : [AVCaptureDevice] { get {
    return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: AVCaptureDevice.Position.unspecified).devices
  } }
#endif

  var cameraList : [String] { get {
    return Self._cameraList.map(\.localizedName)
  }}

}
