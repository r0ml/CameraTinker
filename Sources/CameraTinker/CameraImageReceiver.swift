// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import SceneKit
import AVFoundation

public protocol CameraImageReceiver : Sendable {
  associatedtype Recognizer : RecognizerProtocol
  associatedtype CameraData : Actor

  var textureUpdater : TextureUpdater<Self> { get }

  func start( /* _ perform: @escaping (CameraData) -> () */ )
  @MainActor func updateTexture(_ d : CameraData) async
  func isSceneStable(_ d : CameraData) async -> Bool

  func processFrame(_ d : CameraData) async

  func scene() -> SCNScene
  func resume()
  func pause()

  var recognizer : Recognizer { get }
}

extension AVCaptureDevice {
  static func haveAccess() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      return true
    case .denied:
      return false
    case .restricted:
      return false
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: AVMediaType.video)
    default:
      // this should never happen
      return false
    }
  }
}

/*
/* I don't use the front camera -- it can't focus */
public func globalUpdateTexture(_ pixelBuffer : CVPixelBuffer, _ pf : MTLPixelFormat, _ tx : inout MTLTexture?, _ region : inout MTLRegion?, _ scenex : SCNScene) -> CGSize? {
  let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)

  var res : CGSize? = nil

  if tx == nil || tx!.width != CVPixelBufferGetWidth(pixelBuffer) || tx!.height != CVPixelBufferGetHeight(pixelBuffer) {
    setupTexture( CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)), pf, &tx, &region, scenex )
    res = CGSize(width: tx!.width, height: tx!.height)
  }
  //    if let tx = tx
  // , tx.width == CVPixelBufferGetWidth(pixelBuffer)   // making sure the frame texture matches the pixel buffer (could be off for a frame or two following resizing)
  //    {
  CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
  if let dd = CVPixelBufferGetBaseAddress(pixelBuffer) {
    //          print("update texture \(tx.width)x\(tx.height), bytes per row \(bpr), \(CVPixelBufferGetWidth(pixelBuffer))x\(CVPixelBufferGetHeight(pixelBuffer))")

    tx!.replace(region: region!, mipmapLevel: 0, withBytes: dd, bytesPerRow: bpr)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly);
  }
  CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
  //    } else {
  //      fatalError("frameTexture and pixel buffer sizes don't match")
  //    }
  return res
}

public func globalUpdateTexture(_ d : CIImage, _ pf : MTLPixelFormat, _ tx : inout MTLTexture?, _ region: inout MTLRegion?, _ scenex : SCNScene ) -> CGSize? {
  let p = d
  let siz = p.extent.size

  var res : CGSize? = nil

  if tx == nil || CGFloat(tx!.width) != siz.width || CGFloat(tx!.height) != siz.height {
    log.debug("setup texture \(siz.width)x\(siz.height)")
    setupTexture(siz, pf, &tx, &region, scenex)
    res = CGSize(width: tx!.width, height: tx!.height)
  }
  cic.render(p, to: tx!, commandBuffer: nil, bounds: p.extent, colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)! )
  return res
}


private func setupTexture(_ s : CGSize, _ thePixelFormat : MTLPixelFormat, _ frameTexture: inout MTLTexture?, _ region:  inout MTLRegion?, _ scenex : SCNScene) {
  log.debug("\(#function)")
  let w = Int(s.width)
  let h = Int(s.height)
  if frameTexture?.height != h || frameTexture?.width != w {
    log.debug("allocating texture \(w)x\(h)")
    let mtd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: thePixelFormat, width: w, height: h, mipmapped: false)

    // Need this for AR.  Not needed for Camera
    mtd.usage = [.shaderRead, .shaderWrite]

    let tx = device.makeTexture(descriptor: mtd)
    tx?.label = "webcam frame"
    tx?.setPurgeableState(.keepCurrent)

    scenex.background.contents = nil
    
    region = MTLRegionMake2D(0, 0, mtd.width, mtd.height)
    frameTexture = tx

    scenex.background.contents = frameTexture

#if os(macOS) || targetEnvironment(macCatalyst)
    // since the built in video mirroring seems to only work on the preview layer, and the preview layer doesn't work on ios,
    // I wind up manually doing the mirroring on macOS
    scenex.background.contentsTransform = SCNMatrix4MakeScale(-1, 1, 1)
#endif

    // this when AR
    //    scenex.background.contentsTransform = SCNMatrix4MakeScale(1, -1, 1) // left-right and up-down mirroring when AR
  }
}
*/
