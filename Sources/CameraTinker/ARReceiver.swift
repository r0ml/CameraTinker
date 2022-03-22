// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import SwiftUI

#if os(iOS)

import ARKit

// Store depth-related AR data.
public class ARData {
  var depthImage: CVPixelBuffer?
  var depthSmoothImage: CVPixelBuffer?
  var colorImage: CVPixelBuffer?
  var confidenceImage: CVPixelBuffer?
  var confidenceSmoothImage: CVPixelBuffer?
  var cameraIntrinsics = simd_float3x3()
  var cameraResolution = CGSize(width: 1000, height: 1000)

  var orientation : CGImagePropertyOrientation = .rightMirrored

  init(frame: ARFrame? = nil) {
    depthImage = frame?.sceneDepth?.depthMap
    depthSmoothImage = frame?.smoothedSceneDepth?.depthMap
    colorImage = frame?.capturedImage
    confidenceImage = frame?.sceneDepth?.confidenceMap
    confidenceSmoothImage = frame?.smoothedSceneDepth?.confidenceMap
    cameraIntrinsics = frame?.camera.intrinsics ?? simd_float3x3()
    cameraResolution = frame?.camera.imageResolution ?? CGSize(width: 1000, height: 1000)
  }

  func imageAdjustedForOrientation() -> CIImage {
    CVPixelBufferLockBaseAddress(colorImage!, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(colorImage!, .readOnly) }
    let p = CIImage(cvPixelBuffer: colorImage!).oriented( orientation )
    return p // .oriented(.downMirrored)
  }

  func depthAdjustedForOrientation() -> CIImage {
    CVPixelBufferLockBaseAddress(depthSmoothImage!, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(depthSmoothImage!, .readOnly) }
    let p = CIImage(cvPixelBuffer: depthSmoothImage!).oriented( orientation )
    return p
  }

  /*
   var orientation : CGImagePropertyOrientation {
   let prt = CameraManager<NullRecognizer>.currentOrientation
   let jj : CGImagePropertyOrientation
   switch prt {
   case .landscapeRight: jj = .upMirrored
   case .landscapeLeft: jj = .downMirrored
   case .portrait: jj = .rightMirrored
   default: jj = .left
   }
   return jj
   }
   */
}

// Configure and run an AR session to provide the app with depth-related AR data.
public final class ARReceiver<T : RecognizerProtocol>: NSObject, ARSessionDelegate, CameraImageReceiver,
// FIXME: check this
@unchecked Sendable {
  public var textureUpdater = TextureUpdater()

  public typealias CameraData = ARData

  var arData = ARData()
  var arSession = ARSession()
  public var recognizer : T
  var config = ARWorldTrackingConfiguration()

  public var aspect : CGSize {
    return config.videoFormat.imageResolution
  }

  public func setUseDepth(_ : Bool) {  }
  
  public init(_ r : T) {
    recognizer = r
    super.init()
    arSession.delegate = self
    arSession.delegateQueue = DispatchQueue(label: "AR delegate")

    if ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
      // Enable both the `sceneDepth` and `smoothedSceneDepth` frame semantics.
      config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
    }
  }

  public var isAR : Bool = true

  public func changeCamera(_ x : String) {
    fatalError("AR camera can't be changed!")
  }
  
  // Configure and run the ARKit session.
  public func start(/*_ perform: @escaping (ARData) -> () */ ) {
    arSession.run(config, options: [.resetTracking, .resetSceneReconstruction ])
  }

  public func sessionFn(_ sb : ARData) {
    self.updateTexture(sb)
    if self.isSceneStable( sb ) {
      //  showDetectionOverlay(true)
      self.processFrame(sb)
    }
  }

  /// not able to get the capture device in ARSession
  public var captureDevice : AVCaptureDevice? = nil

  public func resume() {
    start()
  }

  public func pause() {
    arSession.pause()
  }

  var busy = false

  // Process the `ARFrame`
  public func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard case .normal = frame.camera.trackingState else {
      return }
    guard !busy else {
      return }

    self.busy = true
    defer { self.busy = false }
    if (frame.sceneDepth != nil) && (frame.smoothedSceneDepth != nil) {
      self.arData = ARData.init(frame: frame)
      self.sessionFn(self.arData)
    }
  }

  public func scene() -> SCNScene {
    return textureUpdater.getScene()
  }

  public func updateTexture(_ d : CameraData) {
    return textureUpdater.updateTextureImage(d.imageAdjustedForOrientation() )
  }

  var stabilizer = SceneStabilizer()

  public func isSceneStable(_ d : CameraData) -> Bool {
    if let dd = d.colorImage {
      return stabilizer.isSceneStable(pixelBuffer: dd)
    } else {
      return false
    }
  }

  public func processFrame(_ d : CameraData) {
    let da = d.imageAdjustedForOrientation()
    let dd = d.depthAdjustedForOrientation()

    let idd = ImageWithDepth( da, depthImage: dd )
    recognizer.scanImage( idd )
  }

  // from https://developer.apple.com/documentation/arkit/displaying_an_ar_experience_with_metal
  //  var capturedImageTextureCache : CVMetalTextureCache?

  /*
   var capturedImageTextureY : MTLTexture?
   var capturedImageTextureCbCr : MTLTexture?

   func updateCapturedImageTextures(frame: ARFrame) {
   // Create two textures (Y and CbCr) from the provided frame's captured image
   let pixelBuffer = frame.capturedImage
   if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
   return
   }
   capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.r8Unorm, planeIndex:0)!
   capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.rg8Unorm, planeIndex:1)!
   }

   func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
   var mtlTexture: MTLTexture? = nil
   let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
   let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

   var texture: CVMetalTexture? = nil
   let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache!, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
   if status == kCVReturnSuccess {
   mtlTexture = CVMetalTextureGetTexture(texture!)
   }
   return mtlTexture
   }
   */


}

#endif
