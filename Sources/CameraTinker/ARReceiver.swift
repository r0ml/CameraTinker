// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import SwiftUI

#if os(iOS)

import ARKit

// Store depth-related AR data.
public actor ARData {
  var depthImage: CVPixelBuffer?
  var depthSmoothImage: CVPixelBuffer?
  var colorImage: CVPixelBuffer?
  var confidenceImage: CVPixelBuffer?
  var confidenceSmoothImage: CVPixelBuffer?
  var cameraIntrinsics = simd_float3x3()
  var cameraResolution = CGSize(width: 1000, height: 1000)

  init(frame: ARFrame? = nil) {
    depthImage = frame?.sceneDepth?.depthMap
    depthSmoothImage = frame?.smoothedSceneDepth?.depthMap
    colorImage = frame?.capturedImage
    confidenceImage = frame?.sceneDepth?.confidenceMap
    confidenceSmoothImage = frame?.smoothedSceneDepth?.confidenceMap
    cameraIntrinsics = frame?.camera.intrinsics ?? simd_float3x3()
    cameraResolution = frame?.camera.imageResolution ?? CGSize(width: 1000, height: 1000)
  }

  func imageAdjustedForOrientation() async -> CIImage {
    CVPixelBufferLockBaseAddress(colorImage!, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(colorImage!, .readOnly) }
    let p = CIImage(cvPixelBuffer: colorImage!).oriented( await orientation )
    return p
  }

  func depthAdjustedForOrientation() async -> CIImage {
    CVPixelBufferLockBaseAddress(depthSmoothImage!, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(depthSmoothImage!, .readOnly) }
    let p = CIImage(cvPixelBuffer: depthSmoothImage!).oriented( await orientation )
    return p
  }

  @MainActor var orientation : CGImagePropertyOrientation {
    let prt = CameraManager<NullRecognizer>.currentOrientation
    let jj : CGImagePropertyOrientation
    switch prt {
    case .landscapeRight: jj = .up
    case .landscapeLeft: jj = .down
    case .portrait: jj = .right
    default: jj = .right
    }
    return jj
  }
}

// Configure and run an AR session to provide the app with depth-related AR data.
public final class ARReceiver<T : RecognizerProtocol>: NSObject, ARSessionDelegate, CameraImageReceiver,
// FIXME: check this
@unchecked Sendable {
  public var textureUpdater = TextureUpdater()

  public typealias CameraData = ARData

  var arData = ARData()
  var arSession = ARSession()
//  var f : ((ARData) -> ())?
  public var recognizer : T

  public var aspect : CGSize = .zero

  public init(_ r : T) {
    recognizer = r
    CVMetalTextureCacheCreate(nil, nil, device, nil, &capturedImageTextureCache)
//    cic = CIContext(mtlDevice: device)
    super.init()
    arSession.delegate = self

  }

  // Configure and run the ARKit session.
  public func start(/*_ perform: @escaping (ARData) -> () */ ) {
    guard ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) else { return }
    // Enable both the `sceneDepth` and `smoothedSceneDepth` frame semantics.
    let config = ARWorldTrackingConfiguration()
    config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
//    f = perform
    arSession.run(config)
  }

  public func sessionFn(_ sb : ARData) {
      Task.detached(priority: .background) {
        await self.updateTexture(sb)
      if await self.isSceneStable( sb ) {
        //  showDetectionOverlay(true)
          await self.processFrame(sb)
      }
    }
  }
  
  public func resume() {
    start()
  }

  public func pause() {
    arSession.pause()
  }

  // Process the `ARFrame`
  public func session(_ session: ARSession, didUpdate frame: ARFrame) {
    if(frame.sceneDepth != nil) && (frame.smoothedSceneDepth != nil) {
      arData = ARData.init(frame: frame)
      Task.detached(priority: .background) {
      self.sessionFn(self.arData)
      }
    }
  }

  public func scene() -> SCNScene {
    return textureUpdater.scenex
  }

  @MainActor public func updateTexture(_ d : CameraData) async {
    return await textureUpdater.globalUpdateTexture(d.imageAdjustedForOrientation() )
  }

  var stabilizer = SceneStabilizer()

  public func isSceneStable(_ d : isolated CameraData) async -> Bool {
    if let dd = d.colorImage {
      return await stabilizer.isSceneStable(pixelBuffer: dd)
    } else {
      return false
    }
  }

  // from https://developer.apple.com/documentation/arkit/displaying_an_ar_experience_with_metal
  var capturedImageTextureCache : CVMetalTextureCache?
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


  public func processFrame(_ d : CameraData) async {
    let da = await d.imageAdjustedForOrientation()
    let dd = await d.depthAdjustedForOrientation()

    let idd = ImageWithDepth( da, depthImage: dd )
    await recognizer.scanImage( idd )
  }

}

#endif

