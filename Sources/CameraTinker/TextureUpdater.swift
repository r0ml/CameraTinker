// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Metal
import CoreVideo
import SceneKit
import CoreMedia

public class TextureUpdater : @unchecked Sendable {
  var thePixelFormat = MTLPixelFormat.bgra8Unorm
  //  var thePixelFormat = MTLPixelFormat.depth32Float // could be bgra8Unorm_srgb
  public var scenex = SCNScene()
  var cic : CIContext

  var frameTexture : MTLTexture?
  var region : MTLRegion?

  public init() {
    cic = CIContext(mtlDevice: device)
  }

  private func setupTexture(_ s : CGSize) {
    log.debug("\(#function)")
    let w = Int(s.width)
    let h = Int(s.height)

    if frameTexture == nil || frameTexture?.height != h || frameTexture?.width != w {
    log.debug("allocating texture \(w)x\(h)")
    let mtd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: thePixelFormat, width: w, height: h, mipmapped: false)

    // Need this for AR.  Not needed for Camera
    mtd.usage = [.shaderRead, .shaderWrite] // .pixelFormatView

    let tx = device.makeTexture(descriptor: mtd)
    tx?.label = "texture for scene"
    tx?.setPurgeableState(.keepCurrent) // .nonVolatile

    scenex.background.contents = nil

    region = MTLRegionMake2D(0, 0, mtd.width, mtd.height)
    frameTexture = tx

    scenex.background.contents = frameTexture

#if os(macOS) || targetEnvironment(macCatalyst)
    // since the built in video mirroring seems to only work on the preview layer, and the preview layer doesn't work on ios,
    // I wind up manually doing the mirroring on macOS
    scenex.background.contentsTransform = SCNMatrix4MakeScale(-1, 1, 1)
#endif

/*      #if os(macOS)
      let pi = CGFloat.pi/2
      #else
      let pi = Float.pi / 2
      #endif
      depthScene.background.contentsTransform = SCNMatrix4MakeRotation( pi, 0, 0, 1)
*/
    // this when AR
    //    scenex.background.contentsTransform = SCNMatrix4MakeScale(1, -1, 1) // left-right and up-down mirroring when AR
  }
}

  // I don't use the front camera -- it can't focus
  public func updateTextureBuffer(_ pixelBuffer : CVPixelBuffer) {
    let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)

    if frameTexture == nil || frameTexture!.width != CVPixelBufferGetWidth(pixelBuffer) || frameTexture!.height != CVPixelBufferGetHeight(pixelBuffer) {
      setupTexture( CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)) )
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    if let dd = CVPixelBufferGetBaseAddress(pixelBuffer) {
      frameTexture!.replace(region: region!, mipmapLevel: 0, withBytes: dd, bytesPerRow: bpr)
      CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly);
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
  }

  public func updateTextureImage(_ d : CIImage) {
    let p = d
    let siz = p.extent.size
    if frameTexture == nil || CGFloat(frameTexture!.width) != siz.width || CGFloat(frameTexture!.height) != siz.height {
      log.debug("setup texture \(siz.width)x\(siz.height)")
      setupTexture(siz)
    }
    cic.render(p, to: frameTexture!, commandBuffer: nil, bounds: p.extent, colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)! )
  }

}
