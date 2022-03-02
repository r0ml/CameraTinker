// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import AVFoundation
import SwiftUI
import SceneKit

#if os(iOS)
import ARKit
#endif

/**
 This is the camera preview.
 In order to do a preview in SwiftUI, I'm using SceneKit -- which allows passing in a AVCaptureVideoPreviewLayer as a MaterialProperty.
 This works in macOS, but -- sadly -- does not work in iOS.
 // FIXME:  If AVCaptureVideoPreviewLayer starts to work in SceneKit on iOS -- use it.
 
 In this case of iOS, one can use an MTLTexture which can be quickly updated from a CVPixelBuffer.  This is slower than the AVCaptureVideoPreviewLayer approach, but better than nothing. The alternative would be to wrap a UIView as a UIViewRepresentable and then use the AVCaptureVideoPreviewLayer
 
 The documentation also states that one can use an AVCaptureDevice directly as a MaterialProperty -- but when one does so, the AVCaptureVideoDataOutputSampleBufferDelegate doesn't fire -- so one gets the preview, but not access to the  sample buffer in order to run the barcode recognition.
 */

class SceneCoordinator : NSObject, SCNSceneRendererDelegate, ObservableObject {
  var debugOptions: SCNDebugOptions = []
#if DEBUG
  var showStats = true
#else
  var showStats = false
#endif
  
  // for debug mode -- show rendering statistics
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//    renderer.showsStatistics = self.showStats
//    renderer.debugOptions = self.debugOptions
  }
}

enum CameraState {
  case ar
  case camera
  case preview
  case unauthorized
  case uninitialized
}

final class CameraStateObject : NSObject, ObservableObject {
  @Published var cameraState : CameraState = .uninitialized
}

@MainActor public struct PreviewView<U : CameraImageReceiver> : View {

//  @AppStorage("camera name") var cameraName : String = "no camera"

  /// Since the aspect ratio needs to be updated when I found out what the camera image
  /// aspect ratio is, this cannot be a `@State` variable.  It must be an `@ObservedObject`
  /// if it gets set from some exogenous source.

  @ObservedObject var cameraState = CameraStateObject()
  @Binding var cameraName : String

  var imageReceiver : U
#if os(macOS)
  var regularVerticalSizeClass = false
#elseif os(iOS)
  // Placing these here causes this view (and its subviews) to be regenerated when
  // the aspect ratios change (rotation or side-by-side)
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  @Environment(\.verticalSizeClass) var verticalSizeClass

  var regularVerticalSizeClass : Bool { verticalSizeClass == .regular }
#endif


  public init(cameraName cn : Binding<String>, imageReceiver ir : U) {
    _cameraName = cn
    imageReceiver = ir
  }

  func getState() async {
    var res : CameraState = .uninitialized
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
      // if I'm in a preview.......
      res = .preview
    } else if await AVCaptureDevice.haveAccess() {
      #if os(macOS)
      res = .camera
      #else
      if let _ = imageReceiver as? ARReceiver<U.Recognizer>,
          ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
        res = .ar
      } else {
        res = .camera
      }
      #endif
    } else {
      res = .unauthorized
    }
    let aa = res
    self.cameraState.cameraState = aa
  }

  public var body : some View {

    if self.cameraState.cameraState == .ar {
      return AnyView(body2)
    } else if cameraState.cameraState == .camera {
      return AnyView(body1)
    } else if cameraState.cameraState == .uninitialized {
      Task {
        await getState()
      }
      return AnyView( EmptyView() )
    } else {
      return AnyView(body3)
    }
  }

  var body3 : some View {
    Text("To use the camera, you must go into Settings > Privacy > Camera and enable Librorum.")
                      .padding(20)
  }

  var stabilizer = SceneStabilizer()

  var body2 : some View {
    let _ = imageReceiver.start()
    return sceneView
  }

  var body1 : some View {
     VStack {
        CameraPicker(cameraName: $cameraName)
        sceneView
      }.onChange(of: cameraName) {z in
        imageReceiver.changeCamera(cameraName) //  as? CameraManager<U.Recognizer>)?.cameraDidChange()
      }.onAppear {
        imageReceiver.start()
      }
  }

  var sceneView : some View {
    get {
        SceneView(scene: imageReceiver.scene()
                , options: [  .rendersContinuously ]
                , antialiasingMode: .none
                , delegate: SceneCoordinator() )
        .cornersOverlay(imageReceiver.recognizer.sweetSpotSize)

        .border(Color.green, width: 5)
        .aspectRatio( regularVerticalSizeClass ?
                      CGSize(width: imageReceiver.aspect.height, height: imageReceiver.aspect.width)
                      : imageReceiver.aspect
                      , contentMode: .fit)
        .onAppear {
          Task {
            await getState()
          }
          imageReceiver.resume()
        }
        .onDisappear {
          imageReceiver.pause()
        }
    }
  }
}

struct CameraView_Preview : PreviewProvider {
  @State static var cameraName : String = "no camera"
  static var previews : some View {
    CameraPicker(cameraName: $cameraName)
  }
}

/*
struct PreviewView_Preview : PreviewProvider {
  static var sweetSpotSize = CGSize(width: 0.5, height: 0.5)
  static var cr = CameraManager(NullRecognizer())
  static var previews: some View {
    Group {
#if os(macOS)
      PreviewView(imageReceiver: cr)
        .previewDevice("Mac")
        .previewLayout(.fixed(width: 400, height: 300))
        .background(Color.green)
#elseif os(iOS)
      PreviewView(imageReceiver: cr).previewDevice("iPhone X")
      PreviewView(imageReceiver: cr).previewDevice("iPad Pro (12.9-inch) (4th generation)")
        .previewLayout(.fixed(width: 1366, height: 1024))
#endif
    }
  }
}
*/
